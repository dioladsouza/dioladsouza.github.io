package models

import "time"

// This file defines the News struct which represents a news article.
// It includes fields for the title, description, link, publication date, and author.
// The struct is tagged with JSON field names for easy serialization and deserialization.
// The time.Time type is used for the publication date to handle date and time properly.
type News struct {
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Link        string    `json:"link"`
	PubDate     time.Time `json:"pub_date"`
	Author      string    `json:"author"`
	Topic       string    `json:"topic"`
	Priority    string    `json:"priority"` //high, low
}
