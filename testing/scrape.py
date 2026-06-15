from bs4 import builder
from sys import get_coroutine_origin_tracking_depth
from os import MFD_HUGE_SHIFT
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin

BASE_URL = input("Give the URL: ")  

def scrape_directory(url):
    print(f"Fetching data from: {url}...\n")
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching the page: {e}")
        return

    soup = BeautifulSoup(response.text, 'html.parser')
    
    # Locate the file table body
    table_rows = soup.select("#fileTable tbody tr")
    
    if not table_rows:
        print("No entries found in the file table.")
        return


    # Define headers for formatting
    header_line = f"{'Name':<20} | {'Type':<12} | {'Relative URL':<20} | {'Full URL'}"
    separator = "-" * 90

    # Open the file for writing (using UTF-8 to avoid encoding issues)
    with open("scraped_directory.txt", "w", encoding="utf-8") as file:
        # Write headers to both terminal and file
        print(header_line)
        print(separator)
        file.write(header_line + "\n")
        file.write(separator + "\n")

        # Loop through each row that has data-entry="true"
        for row in table_rows:
            if row.get('data-entry') == 'true':
                name = row.get('data-name', 'Unknown')
                relative_url = row.get('data-url', '')
                full_url = urljoin(url, relative_url)
                
                # Find the type label (e.g., "Directory")
                type_span = row.find('span', class_='type-label')
                item_type = type_span.text.strip() if type_span else "File"
                
                # Format the data row
                row_data = f"{name:<20} | {item_type:<12} | {relative_url:<20} | {full_url}"
                
                # Write to terminal and file
                print(row_data)
                file.write(row_data + "\n")
                
    print("\n[Success] Results have been saved to 'scraped_directory.txt'")

if __name__ == "__main__":
    scrape_directory(BASE_URL)


