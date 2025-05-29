package service

// This file contains the gossip protocol implementation.

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net"
	"sync"
	"time"

	//"github.com/segmentio/kafka-go"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pb "newslet-main/api/proto"
)

// News struct
type News struct {
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Link        string    `json:"link"`
	PubDate     time.Time `json:"pub_date"`
	Author      string    `json:"author"`
	Priority    string    `json:"priority"` //high, low
}

// GossipNode represents a node in the gossip network
type GossipNode struct {
	pb.UnimplementedGossipServiceServer

	ID            string
	Addr          string
	Peers         []string
	NewsItems     map[string]News
	NewsItemsLock sync.RWMutex
	KafkaWriter   *kafka.Writer
	Leader        bool
	LeaderLock    sync.RWMutex
	grpcServer    *grpc.Server
}

// NewGossipNode creates a new gossip node
func NewGossipNode(id, addr string, peers []string, kafkaBrokers []string) *GossipNode {
	return &GossipNode{
		ID:        id,
		Addr:      addr,
		Peers:     peers,
		NewsItems: make(map[string]News),
		KafkaWriter: &kafka.Writer{
			Addr:     kafka.TCP(kafkaBrokers...),
			Balancer: &kafka.LeastBytes{},
		},
		Leader: false,
	}
}

// Start begins the gossip node operations
func (n *GossipNode) Start() {
	// Start gRPC server
	go n.startGRPCServer()

	// Start gossip loop
	go n.gossipLoop()

	// Start leader election
	go n.leaderElectionLoop()

	// Start processing news items
	go n.processNewsItems()
}

func (n *GossipNode) startGRPCServer() {
	lis, err := net.Listen("tcp", n.Addr)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	n.grpcServer = grpc.NewServer()
	pb.RegisterGossipServiceServer(n.grpcServer, n)

	log.Printf("gRPC server listening at %v", lis.Addr())
	if err := n.grpcServer.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}

// Gossip implements the gRPC service method
func (n *GossipNode) Gossip(ctx context.Context, msg *pb.GossipMessage) (*pb.GossipAck, error) {
	var items []News
	for _, item := range msg.Items {
		items = append(items, News{
			Title:       item.Title,
			Description: item.Description,
			Link:        item.Link,
			PubDate:     time.Unix(0, item.PubDate),
			Author:      item.Author,
			Priority:    item.Priority,
		})
	}

	n.processReceivedItems(items)
	return &pb.GossipAck{Success: true}, nil
}

func (n *GossipNode) gossipLoop() {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		if len(n.Peers) == 0 {
			continue
		}

		// Select random peer
		peer := n.Peers[rand.Intn(len(n.Peers))]

		// Get items to gossip
		items := n.selectItemsToGossip()
		if len(items) == 0 {
			continue
		}

		// Send to peer via gRPC
		if err := n.sendGossip(peer, items); err != nil {
			log.Printf("Error sending gossip to %s: %v", peer, err)
		}
	}
}

func (n *GossipNode) sendGossip(peer string, items []News) error {
	conn, err := grpc.Dial(peer, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return err
	}
	defer conn.Close()

	client := pb.NewGossipServiceClient(conn)

	var pbItems []*pb.News
	for _, item := range items {
		pbItems = append(pbItems, &pb.News{
			Title:       item.Title,
			Description: item.Description,
			Link:        item.Link,
			PubDate:     item.PubDate.UnixNano(),
			Author:      item.Author,
			Priority:    item.Priority,
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	_, err = client.Gossip(ctx, &pb.GossipMessage{
		Items:    pbItems,
		SenderId: n.ID,
	})
	return err
}

func (n *GossipNode) selectItemsToGossip() []News {
	n.NewsItemsLock.RLock()
	defer n.NewsItemsLock.RUnlock()

	var items []News
	// Select up to 5 random items to gossip
	count := 0
	for _, item := range n.NewsItems {
		items = append(items, item)
		count++
		if count >= 5 {
			break
		}
	}
	return items
}

func (n *GossipNode) processReceivedItems(items []News) {
	n.NewsItemsLock.Lock()
	defer n.NewsItemsLock.Unlock()

	for _, item := range items {
		// Check if item is available or it's an older version
		if existing, exists := n.NewsItems[item.Title]; !exists || existing.PubDate.Before(item.PubDate) {
			n.NewsItems[item.Title] = item
			log.Printf("Added/updated news item %s", item.Title)
		}
	}
}

func (n *GossipNode) AddNewsItem(item News) {
	n.NewsItemsLock.Lock()
	defer n.NewsItemsLock.Unlock()

	if item.PubDate.IsZero() {
		item.PubDate = time.Now()
	}

	n.NewsItems[item.Title] = item
	log.Printf("Added new news item %s", item.Title)
}

func (n *GossipNode) processNewsItems() {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		n.NewsItemsLock.Lock()

		// Process items based on priority
		for title, item := range n.NewsItems {
			// Only the leader publishes to Kafka
			if n.isLeader() {
				// High priority items get published immediately and Low priority items wait at least 30 seconds
				if item.Priority == "high" && time.Since(item.PubDate) > time.Second {
					n.publishToKafka(item)
					delete(n.NewsItems, title)
				} else if item.Priority == "low" && time.Since(item.PubDate) > 30*time.Second {
					n.publishToKafka(item)
					delete(n.NewsItems, title)
				}
			}
		}

		n.NewsItemsLock.Unlock()
	}
}

func (n *GossipNode) publishToKafka(item News) {
	jsonData, err := json.Marshal(item)
	if err != nil {
		log.Printf("Error marshaling news item: %v", err)
		return
	}

	err = n.KafkaWriter.WriteMessages(context.Background(),
		kafka.Message{
			Key:   []byte(item.Author),
			Value: jsonData,
		},
	)

	if err != nil {
		log.Printf("Error publishing to Kafka: %v", err)
	} else {
		log.Printf("Published news item %s to topic %s", item.Title, item.Description)
	}
}

func (n *GossipNode) isLeader() bool {
	n.LeaderLock.RLock()
	defer n.LeaderLock.RUnlock()
	return n.Leader
}

func (n *GossipNode) leaderElectionLoop() {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		//leader election -- to be replaced with Jacky's code
		if rand.Intn(2) == 0 {
			n.LeaderLock.Lock()
			n.Leader = true
			n.LeaderLock.Unlock()
			log.Printf("I am now the leader")
		} else {
			n.LeaderLock.Lock()
			n.Leader = false
			n.LeaderLock.Unlock()
		}
	}
}

func (n *GossipNode) Stop() {
	if n.grpcServer != nil {
		n.grpcServer.GracefulStop()
	}
}

func main() {
	// Configuration
	nodeID := "node1"
	nodeAddr := ":50051"
	peers := []string{"localhost:50052", "localhost:50053"} // other nodes
	kafkaBrokers := []string{"localhost:9092"}

	// Create and start node
	node := NewGossipNode(nodeID, nodeAddr, peers, kafkaBrokers)
	node.Start()

	// Simulate adding news items
	go func() {
		authors := []string{"a", "b", "c"}
		for i := 0; i < 20; i++ {
			priority := "low"
			if rand.Intn(10) < 3 { // 30% chance of high priority
				priority = "high"
			}

			item := News{
				Title:       fmt.Sprintf("Breaking News %d", i),
				Description: fmt.Sprintf("Detailed description of news item %d", i),
				Link:        fmt.Sprintf("https://news.example.com/%d", i),
				PubDate:     time.Now().Add(-time.Duration(rand.Intn(60)) * time.Minute), // Random time in past 60 mins
				Author:      authors[rand.Intn(len(authors))],
				Priority:    priority,
			}
			node.AddNewsItem(item)
			time.Sleep(time.Duration(rand.Intn(3)) * time.Second)
		}
	}()

	// Block forever
	select {}
}
