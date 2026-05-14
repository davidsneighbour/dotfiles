# shellcheck shell=bash

dnb_to_lower() {
  # Locale-stable lowercase conversion
  LC_ALL=C tr '[:upper:]' '[:lower:]'
}
