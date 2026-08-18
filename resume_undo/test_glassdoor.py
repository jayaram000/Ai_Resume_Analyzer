import os
import requests
import json

api_key = os.getenv("JSEARCH_API_KEY", "e37149c209msh4fb3794708cfc72p13ae24jsnb3e5065ab299")

url = "https://glassdoor-real-time.p.rapidapi.com/jobs/search"
headers = {
    "X-RapidAPI-Key": api_key,
    "X-RapidAPI-Host": "glassdoor-real-time.p.rapidapi.com"
}
params = {"query": "flutter in kochi"}
response = requests.get(url, headers=headers, params=params)
print(response.status_code)
data = response.json()
listings = data.get("data", {}).get("jobListings", [])
print(f"Count: {len(listings)}")
if listings:
    print(listings[0].get("jobview", {}).get("job", {}).get("jobTitleText"))
    print(listings[0].get("jobview", {}).get("header", {}).get("locationName"))
