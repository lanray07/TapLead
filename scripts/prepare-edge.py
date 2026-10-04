"""Copy canonical validation/visibility logic into the self-contained Edge bundle."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / "backend/src/domain.js"
target = root / "supabase/functions/taplead/domain.js"
target.write_bytes(source.read_bytes())
print("Prepared shared card/lead validation for Edge deployment.")
