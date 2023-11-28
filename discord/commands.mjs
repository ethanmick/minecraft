#!/usr/bin/env zx

const url = `https://discord.com/api/v10/applications/1171814846891823104/commands`

const res = await fetch(url, {
  method: 'POST',
  headers: {
    Authorization: `Bot ${process.env.DISCORD_BOT_TOKEN}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    name: 'minecraft',
    description: 'Command the Minecraft server',
  }),
})

const json = await res.json()
console.log(`Update Status: ${res.status}`, json)
