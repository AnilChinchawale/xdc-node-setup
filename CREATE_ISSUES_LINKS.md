# Create GitHub Issues - Quick Links

Click these links to create issues directly on GitHub:

## Issue #1: SkyNet API Heartbeat Failure
**Title:** SkyNet API heartbeat fails for Apothem testnet nodes

**Link:** 
https://github.com/AnilChinchawale/xdc-node-setup/issues/new?title=SkyNet%20API%20heartbeat%20fails%20for%20Apothem%20testnet%20nodes&body=%23%23%20Issue%20Description%0ASkyNet%20heartbeat%20API%20returns%20%22Failed%20to%20process%20heartbeat%22%20error.%0A%0A%23%23%20Environment%0A-%20Node%20ID%3A%206bbd0e18-1133-49a7-ae22-e74888e9081e%0A-%20Network%3A%20Apothem%20Testnet%20(Chain%20ID%3A%2051)%0A%0A%23%23%20Possible%20Causes%0A1.%20SkyNet%20API%20may%20not%20recognize%20Apothem%20testnet%20nodes%20yet%0A2.%20API%20payload%20format%20may%20need%20adjustment%0A3.%20Node%20registration%20may%20need%20update%20for%20testnet%0A%0A%23%23%20Proposed%20Solutions%0A1.%20Contact%20SkyNet%20team%20to%20verify%20testnet%20node%20support%0A2.%20Check%20if%20payload%20needs%20network-specific%20fields%0A3.%20Verify%20node%20registration%20is%20valid%20for%20testnet%0A&labels=bug,skynet,apothem

---

## Issue #2: Erigon Bootnodes Error  
**Title:** Erigon container fails to start with bootnodes error

**Link:**
https://github.com/AnilChinchawale/xdc-node-setup/issues/new?title=Erigon%20container%20fails%20to%20start%20with%20bootnodes%20error&body=%23%23%20Issue%20Description%0AErigon%20fails%20to%20start%20with%20invalid%20bootnodes%20format%20error.%0A%0A%23%23%20Error%20Message%0A%60%60%60%0AInvalid%20node%20URL%20-%20wrong%20public%20key%20length%0A%60%60%60%0A%0A%23%23%20Proposed%20Solutions%0A1.%20Remove%20bootnodes%20parameter%20temporarily%0A2.%20Fix%20bootnodes%20format%20for%20Erigon%0A3.%20Use%20embedded%20XDC%20bootnodes%0A&labels=bug,erigon,bootnodes

---

## Issue #3: Multi-Client Dashboard
**Title:** Multi-client dashboard should display both Geth and Erigon stats

**Link:**
https://github.com/AnilChinchawale/xdc-node-setup/issues/new?title=Multi-client%20dashboard%20should%20display%20both%20Geth%20and%20Erigon%20stats&body=%23%23%20Feature%20Request%0AEnhance%20dashboard%20to%20show%20metrics%20from%20both%20Geth%20and%20Erigon%20clients%20simultaneously.%0A%0A%23%23%20Current%20State%0A-%20Dashboard%20only%20shows%20Geth%20(xdc-node)%20metrics%0A-%20Erigon%20runs%20on%20ports%208555%2F8556%0A%0A%23%23%20Proposed%20Implementation%0A1.%20Add%20second%20metrics%20endpoint%20for%20Erigon%0A2.%20Display%20both%20clients%20in%20UI%20with%20labels%0A3.%20Show%20sync%20progress%20comparison%0A4.%20Alert%20if%20one%20client%20falls%20behind%0A&labels=enhancement,dashboard,multi-client

---

## Alternative: Create via GitHub CLI

If you have GitHub CLI installed and authenticated:

```bash
# Authenticate
gh auth login

# Create Issue #1
gh issue create \
  --title "SkyNet API heartbeat fails for Apothem testnet nodes" \
  --body "SkyNet heartbeat API returns Failed to process heartbeat error. Node ID: 6bbd0e18-1133-49a7-ae22-e74888e9081e" \
  --label "bug,skynet,apothem"

# Create Issue #2  
gh issue create \
  --title "Erigon container fails to start with bootnodes error" \
  --body "Erigon fails with invalid bootnodes format. Need to fix bootnodes configuration." \
  --label "bug,erigon,bootnodes"

# Create Issue #3
gh issue create \
  --title "Multi-client dashboard should display both Geth and Erigon stats" \
  --body "Enhance dashboard to show metrics from both clients simultaneously." \
  --label "enhancement,dashboard,multi-client"
```

---

## Alternative: Create via cURL (with token)

```bash
export GITHUB_TOKEN="ghp_your_token_here"
bash /tmp/create-issues.sh
```
