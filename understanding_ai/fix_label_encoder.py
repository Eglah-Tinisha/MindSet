"""
Regenerates label_encoder.pkl from the training CSV
and saves it into bert_model/
"""
import pickle
import pandas as pd
from sklearn.preprocessing import LabelEncoder

# Load your training data
CSV_PATH  = "data/train.csv"   # adjust if your CSV has a different name/path
MODEL_DIR = "bert_model"

df = pd.read_csv(CSV_PATH)
df = df.dropna(subset=["label"])

le = LabelEncoder()
le.fit(df["label"])

out_path = f"{MODEL_DIR}/label_encoder.pkl"
with open(out_path, "wb") as f:
    pickle.dump(le, f)

print(f"✓ Saved label_encoder.pkl → {out_path}")
print(f"  Classes ({len(le.classes_)}): {list(le.classes_)}")