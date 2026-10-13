# Danish Voice Lines Guide

All voice-over is in **Danish**. Place OGG Vorbis files under:

```
assets/audio/voice/<npc_id>/<line_id>.ogg
```

## Naming convention

`voice_key` in Lua dialogue maps directly to the file path (without `res://assets/audio/` prefix).

Example:
```lua
voice_key = "voice/lyra/greet_1"
```
→ file: `assets/audio/voice/lyra/greet_1.ogg`

## Required lines (initial content)

### Lyra (mayor_lyra)
| Line ID | Danish text |
|---------|-------------|
| `greet_1` | "Velkommen, eventyrrejsende! Jeg er Lyra, feborgmesteren her i PongPong." |
| `greet_2` | "Feernes Konge har udvalgt dig i det årlige lotteri!" |
| `lottery` | "Du har vundet en fortryllet trækronsgård! Den venter på dig i skovens kroner." |
| `hello` | "Godt at se dig igen!" |
| `farm_status` | "Din gård trives! Fortsæt det gode arbejde." |

### Maja (baker_maja)
| Line ID | Danish text |
|---------|-------------|
| `greet` | "Hej der! Velkommen til mit lille bageri." |
| `roof_trouble` | "Åh nej, stormen i går beskadigede mit tag! Kan du hjælpe mig?" |
| `thanks` | "Tak for hjælpen! Taget er som nyt igen." |
| `cookie_talk` | "Jeg bager de bedste småkager i hele PongPong!" |

### Lily (fairy_lily)
| Line ID | Danish text |
|---------|-------------|
| `greet` | "Hej... vil du lege?" |
| `cat_missing` | "Min kat Mjau er væk! Hun løb ind i skovbrynet og kom ikke tilbage..." |
| `worried` | "Har du fundet Mjau endnu? Jeg er så bekymret..." |

### Thorin (smith_thorin)
| Line ID | Danish text |
|---------|-------------|
| `greet` | "Hrmf. Velkommen til smedjen." |
| `mining_talk` | "Den mørke skov er fuld af sjældne malmsten... men også farer." |

## Audio specs

- Format: OGG Vorbis
- Sample rate: 44100 Hz
- Channels: Mono (voice) / Stereo (music/sfx)
- Normalized to -1 dBFS peak
- Trim silence at start/end

## TTS placeholders

Until real voice actors record the lines, use a Danish TTS service to generate placeholder files. Recommended:
1. Paste the Danish text
2. Choose a warm, friendly Danish voice
3. Export as OGG
4. Drop into the correct path

The game falls back gracefully when a voice file is missing (text still displays).
