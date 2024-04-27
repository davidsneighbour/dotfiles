#!/bin/bash

# Usage function to display help
usage() {
  echo "Usage: $0 [--output-dir OUTPUT_DIR]"
  echo "  --output-dir Directory where repositories will be cloned (optional, default is current directory)."
  exit 1
}

# Parsing command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
  --output-dir)
    output_dir="${2%/}" # Remove trailing slash if it exists
    shift
    ;;
  *)
    echo "Unknown parameter passed: $1"
    usage
    ;;
  esac
  shift
done

# Set default output directory if not specified
if [ -z "$output_dir" ]; then
  output_dir="."
fi

# Create output directory if it does not exist
mkdir -p "$output_dir"

# Load GitHub personal access token from ~/.env
if [ -f ~/.env ]; then
  source ~/.env
else
  echo "Error: .env file not found in home directory."
  exit 2
fi

# Check if GitHub token is available
if [ -z "$GITHUB_DEV_TOKEN" ]; then
  echo "Error: GitHub development token not set in .env file."
  exit 3
fi

# Function to fetch and clone repositories
fetch_and_clone_repos() {
  local page=1
  local all_repos_fetched=false

  while [ "$all_repos_fetched" = false ]; do
    response=$(curl -sH "Authorization: token $GITHUB_DEV_TOKEN" "https://api.github.com/user/repos?type=all&per_page=100&page=$page")

    # Check if response contains valid JSON
    if ! echo "$response" | jq . >/dev/null 2>&1; then
      echo "Failed to parse JSON, or got an error from GitHub:"
      echo "$response"
      exit 4
    fi

    # Debugging: Save each page's response
    echo "$response" >"debug_response_page_$page.json"

    # Count repositories in the response
    repo_count=$(echo "$response" | jq -r '. | length')
    if [ "$repo_count" -eq 0 ]; then
      all_repos_fetched=true
      echo "No more repositories to clone."
      break
    fi

    # Attempt to extract clone URLs and clone
    echo "$response" | jq -r '.[] | .name, .ssh_url' | while
      read repo_name
      read ssh_url
    do
      if [ -z "$ssh_url" ]; then
        echo "A repository without a clone URL was encountered: $repo_name"
        continue
      fi
      if [ -d "$output_dir/$repo_name" ]; then
        echo "Directory $output_dir/$repo_name already exists, skipping clone."
        continue
      fi
      echo "Cloning $ssh_url into $output_dir/$repo_name"
      git clone "$ssh_url" "$output_dir/$repo_name"
    done

    ((page++))
  done
}

# Change to output directory
cd "$output_dir"

# Fetch and clone repositories
fetch_and_clone_repos

echo "Repositories cloned in $output_dir"
