
extends Control

@onready var score_label = $ScoreLabel

func update_score(new_score: int):
	score_label.text = "Score: %d" % new_score