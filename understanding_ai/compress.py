# save as compress_model.py — run once then delete
from transformers import BertForSequenceClassification, BertTokenizerFast
import torch

model = BertForSequenceClassification.from_pretrained("bert_model")
tokenizer = BertTokenizerFast.from_pretrained("bert_model")

# Re-save in float16 (half precision) — half the size, same performance
model = model.half()
model.save_pretrained("bert_model_small", safe_serialization=True)
tokenizer.save_pretrained("bert_model_small")

print("Done! Check bert_model_small size.")