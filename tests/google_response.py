"""Compile and check the production response parser without Windows dependencies.

Run from the repository root: python3 tests/google_response.py
Requires g++ (or set CXX).
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile

source = Path('dll/src/translator_core.cpp').read_text()
encoder = source[source.index('static string ConvertCodepointToUTF8'):source.index('// Simple JSON parser')]
parser = source[source.index('string TranslationClient::ParseGoogleFreeResponse'):source.index('TranslationResult TranslationClient::TranslateText')]
first = '给法师能量灌注，保持旗手身上的恢复。'
second = '如果盗贼先手攻击你，使用心灵尖啸，骗掉脚踢后再读条快速治疗。'
sentences = [[first, 'Pop PI on the mage and keep renew rolling on the FC.', None, None, 1, None, [[0, 1]]],
             [second, 'If the rogue opens on you, psychic scream and try to juke the kick before hard casting flash heal.', None, None, 1]]
fixtures = [
    (json.dumps([sentences, None, 'en'], ensure_ascii=False, separators=(',', ':')), first + second),
    (json.dumps([sentences, None, 'en']), first + second),
    ('[[["first", "source", null], ["second", "source", null]], null]', 'firstsecond'),
    ('[[["a ]] bracket", "source"],["b", "source"]],null]', 'a ]] bracketb'),
    (json.dumps([[['quote " and \\ slash', 'source', [['metadata', 'ignore me']]], ['tail', 'source']]]), 'quote " and \\ slashtail'),
    ('[[["one", "source"]],[["metadata", "must not translate"]]]', 'one'),
    ('[[["one", "source"],["two', ''),
    ('[[["one", "source", [[0,1]]', ''),
    ('<html>rate limited</html>', ''),
]
checks = []
for index, (response, expected) in enumerate(fixtures):
    checks.append('if (client.ParseGoogleFreeResponse(' + json.dumps(response) + ') != ' +
                  json.dumps(expected) + ') { std::cerr << "case ' + str(index) + ' failed\\n"; return 1; }')
program = '''#include <string>
#include <iostream>
using namespace std;
class TranslationClient { public: string ParseGoogleFreeResponse(const string&); };
''' + encoder + parser + '\nint main() { TranslationClient client;\n' + '\n'.join(checks) + '\n}\n'
with tempfile.TemporaryDirectory() as directory:
    cpp = Path(directory) / 'response.cpp'
    binary = Path(directory) / 'response'
    cpp.write_text(program)
    subprocess.run([os.environ.get('CXX', 'g++'), '-std=c++17', '-Wall', '-Wextra', str(cpp), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
print(f'Passed {len(fixtures)} production response parser cases')
