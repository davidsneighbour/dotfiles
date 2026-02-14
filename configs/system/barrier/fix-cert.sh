set -euo pipefail

SSL_DIR="${HOME}/.local/share/barrier/SSL"
FP_DIR="${SSL_DIR}/Fingerprints"

mkdir -p "${FP_DIR}"

# Create a self-signed cert + private key in ONE file: Barrier.pem
openssl req -x509 -nodes -days 3650 \
  -subj "/CN=Barrier" \
  -newkey rsa:4096 \
  -keyout "${SSL_DIR}/Barrier.pem" \
  -out "${SSL_DIR}/Barrier.pem"

chmod 700 "${SSL_DIR}"
chmod 600 "${SSL_DIR}/Barrier.pem"

# Generate the server fingerprint file (Barrier commonly uses SHA1 fingerprints)
openssl x509 -fingerprint -sha1 -noout -in "${SSL_DIR}/Barrier.pem" \
  | sed 's/^SHA1 Fingerprint=//' \
  > "${FP_DIR}/Local.txt"

chmod 600 "${FP_DIR}/Local.txt"

echo "Created: ${SSL_DIR}/Barrier.pem"
echo "Fingerprint: $(cat "${FP_DIR}/Local.txt")"
