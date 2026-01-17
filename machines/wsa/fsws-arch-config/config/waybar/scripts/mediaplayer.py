#!/usr/bin/env python3
import json
import subprocess
import sys

try:
    output = subprocess.check_output(['playerctl', 'metadata', '--format', '{"text": "{{artist}} - {{title}}", "tooltip": "{{playerName}} : {{artist}} - {{title}}", "alt": "{{status}}", "class": "{{status}}"}'], universal_newlines=True)
    json_output = json.loads(output)
    json_output['text'] = json_output['text'][:40] + '...' if len(json_output['text']) > 40 else json_output['text']
    print(json.dumps(json_output))
except:
    print('{"text": "", "tooltip": "No media playing"}')
    sys.exit(0)
