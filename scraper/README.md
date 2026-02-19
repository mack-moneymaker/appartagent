# AppartAgent Scraper

Local Playwright scraper that fetches real estate listings from French platforms and pushes them to AppartAgent.

## Platforms
- **LeBonCoin** — largest French classifieds
- **PAP** — particulier à particulier (no agents)
- **Bien'ici** — aggregator
- **SeLoger** — major French real estate portal

## Setup

```bash
cd scraper
npm install
npx playwright install chromium

# Create .env from example
cp .env.example .env
# Edit .env with your API key
```

## Configuration

Create a `.env` file:
```
API_URL=https://appartagent-app.fly.dev
SCRAPER_API_KEY=your_key_here
```

## Usage

```bash
node index.js
```

The scraper will:
1. Fetch active search profiles from the API
2. For each profile, scrape all configured platforms
3. Post found listings back to the API
4. Create alerts for matching search profiles

## Debugging

Failed scrapes save screenshots to `debug/` directory.

## Notes
- Uses a real (non-headless) Chromium browser for anti-bot bypass
- Browser window is positioned offscreen (-9999,-9999)
- Random delays between requests to avoid detection
- If a platform blocks, it logs the error and continues with others
