#!/bin/bash

# Create single-field vector index for product_index collection
# This is required for bare findNearest queries (without filters)

echo "Creating single-field vector index for product_index..."

gcloud firestore indexes composite create \
  --project=freya-7c812 \
  --collection-group=product_index \
  --query-scope=COLLECTION \
  --field-config=field-path=embedding,vector-config='{"dimension":"768","flat":"{}"}'

echo ""
echo "Index creation initiated. Check status with:"
echo "gcloud firestore indexes composite list --project=freya-7c812"
echo ""
echo "Wait until Status = READY before testing product/resolve endpoint."

