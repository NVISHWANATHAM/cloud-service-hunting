#!/bin/bash

echo "Enter the main domain. Example: vulnweb.com!!!"
read domain

# Checking the last status
if [ -f <span class="math-inline">domain/\.status\.txt \]; then
status\=</span>(cat $domain/.status.txt)
  echo "Previous status: $status"
else
  status=0
fi

# Checking if the cloud service permutation phase has been previously chosen
if [ -f <span class="math-inline">domain/\.cloud\_permutation\.txt \]; then
cloud\_permutation\=</span>(cat $domain/.cloud_permutation.txt)
  echo "Cloud service permutation option: $cloud_permutation"
else
  cloud_permutation=0
fi

# ENUMERATION PHASE

if [ $status -le 0 ]; then
  if [ ! -d $domain ]; then
    mkdir $domain
    echo "Created directory: $domain"

    # Cloud service permutation option
    if [ $cloud_permutation -eq 0 ]; then
      echo "Choose the cloud service permutation option:"
      echo "1. Use cloud_enum (It will take a significant amount of time during the enumeration phase)"
      echo "2. Without using cloud_enum"
      read option

      if [ $option -eq 1 ]; then
        cloud_permutation=1
      elif [ $option -eq 2 ]; then
        cloud_permutation=2
      fi

      echo $cloud_permutation > $domain/.cloud_permutation.txt
    fi
  fi

  # Dorking phase
  echo "===== Fase Dorking ====="
  echo "site:.s3.amazonaws.com | site:.storage.googleapis.com | site:.blob.core.windows.net | site:.amazonaws.com | site:.digitaloceanspaces.com" "$domain" | anew $domain/Dorking-Cloud.txt
  echo "Dorking results saved to: $domain/Dorking-Cloud.txt"
  echo 1 > $domain/.status.txt
fi

if [ $status -le 1 ]; then
  echo "===== Fase Enumeration SubDomain ====="
  subfinder -d $domain -silent | anew $domain/subs.txt
  assetfinder -subs-only $domain | anew $domain/subs.txt
  amass enum -passive -d $domain | anew $domain/subs.txt
  echo "Subdomain enumeration results saved to: $domain/subs.txt"
  echo 2 > $domain/.status.txt
fi

if [ $status -le 2 ]; then
  cat $domain/subs.txt | httpx -silent | anew $domain/alive.txt
  echo "Live subdomains saved to: $domain/alive.txt"
  echo 3 > $domain/.status.txt
fi

# Additional phase after status 2
if [ $status -le 3 ]; then
  echo "===== Fase Crawling JS ====="
  cat $domain/alive.txt | katana -jc -o $domain/java.txt
  echo "JavaScript files extracted to: $domain/java.txt"
  echo 4 > $domain/.status.txt
fi

# JavaScript-based cloud domain enumeration phase
if [ $status -le 4 ]; then
  echo "===== Fase Enumeration Cloud From JS ====="
  cat $domain/java.txt | grep -oP '(https?://\S+?\.js\b)' | rush 'python3 ~/Tools/SecretFinder/SecretFinder.py -i {} -o cli' | anew $domain/urlfinder.txt
  cat $domain/urlfinder.txt | grep -Eo '(cloudservice_url|amazon_aws_url).*' | anew $domain/urlcloudjs.txt
  cat $domain/urlcloudjs.txt | grep -o -E '\b([a-zA-Z0-9-]+\.)+[a-zA-Z0-9-]+(:[0-9]+)?(/[\S]*)?\b' | anew $domain/alives.txt
  cat $domain/alive.txt | grep -o -E '\b([a-zA-Z0-9-]+\.)+[a-zA-Z0-9-]+(:[0-9]+)?(/[\S]*)?\b' | sort -u | anew $domain/alives.txt
  echo "Potential cloud URLs found in JS files: $domain/urlcloudjs.txt"
  echo "Extracted potential cloud domains from JS: $domain/alives.txt"
  echo 5 > $domain/.status.txt
fi

# Cloud service permutation with or without cloud_
