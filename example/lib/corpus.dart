/// Values copied from the upstream test corpus
/// (`packages/test-cases/src/cases.ts` and `number-cases.ts`).
class CorpusCase {
  const CorpusCase(this.label, this.values);

  final String label;
  final List<Object> values;
}

const List<CorpusCase> sentenceCases = <CorpusCase>[
  CorpusCase('Word reorder + exit', <Object>[
    'Transaction Safe',
    'Processing Transaction',
  ]),
  CorpusCase('Same word, reversed order', <Object>[
    'hello world',
    'world hello',
  ]),
  CorpusCase('Resemblance across a surviving word', <Object>[
    'Copy Address',
    'Address Copied',
  ]),
  CorpusCase('Character morph + word swap', <Object>[
    'npm i torph',
    'pnpm add torph',
  ]),
  CorpusCase('Number inside a sentence', <Object>[
    '3 unread messages',
    '13 unread messages',
    '9 unread messages',
  ]),
  CorpusCase('Two numbers, one sentence', <Object>[
    '2 of 10 done',
    '2 of 15 done',
    '7 of 15 done',
  ]),
  CorpusCase('Version strings stay text', <Object>[
    'v1.2.3',
    'v1.3.0',
    'v2.0.0',
  ]),
  CorpusCase('Emptying a number to its affix', <Object>[
    r'$4',
    r'$',
    r'$4',
    r'$420',
  ]),
  CorpusCase('Affixes hold while digits churn', <Object>[
    '(1,234)',
    '(5,678)',
    '12%',
    '97%',
  ]),
  CorpusCase('Emoji', <Object>['Hello 👋', 'Goodbye 👋']),
  CorpusCase('Unicode accents', <Object>['café', 'cafe']),
  CorpusCase('RTL text (Arabic)', <Object>['مرحبا بالعالم', 'مرحبا يا صديقي']),
  CorpusCase('Complete replacement', <Object>['abcdef', 'xyz']),
  CorpusCase('Empty to text', <Object>['', 'hello world', '']),
];

const List<CorpusCase> numberCases = <CorpusCase>[
  CorpusCase('Counter tick', <Object>[100, 101, 102, 103]),
  CorpusCase('Integer grows left', <Object>['99', '199', '1,199']),
  CorpusCase('Separator slides up a magnitude', <Object>[
    '999,999',
    '1,000,000',
  ]),
  CorpusCase('Currency to millions', <Object>[r'$999.50', r'$1,000,000.00']),
  CorpusCase('Trailing unit held', <Object>['1.25 MB', '1.5 MB', '999 MB']),
  CorpusCase('Percent sign held', <Object>['0%', '50%', '100%']),
  CorpusCase('Fixed-width clock', <Object>['09:59', '10:00', '10:01']),
  CorpusCase('Delta badge', <Object>['+2.4%', '−0.8%', '+11.2%', '0.0%']),
  CorpusCase('Compact suffix', <Object>['999K', '1.2K', '12.4M', '1.1B']),
  CorpusCase('Scoreline', <Object>['0 - 0', '1 - 0', '1 - 1', '2 - 1']),
  CorpusCase('Currency symbol swaps', <Object>[
    r'$99.00',
    '€99.00',
    '£99.00',
    '¥99.00',
  ]),
  CorpusCase('IDs stay unique', <Object>[
    '1',
    '11',
    '111',
    '1,111',
    '11,111',
    '1,111',
    '111',
    '11',
    '1',
  ]),
];

const List<CorpusCase> multilineCases = <CorpusCase>[
  CorpusCase('Multiline basic', <Object>['hello\nworld', 'hello\nuniverse']),
  CorpusCase('Multiline add line', <Object>[
    'hello world\ngoodbye',
    'hello world\ngoodbye\nfarewell',
  ]),
  CorpusCase('Multiline remove line', <Object>[
    'hello world\nfoo bar\ngoodbye moon',
    'hello world\ngoodbye moon',
  ]),
  CorpusCase('Multiline reorder', <Object>[
    'alpha bravo\ncharlie delta',
    'charlie delta\nalpha bravo',
  ]),
  CorpusCase('A number holds across a new line', <Object>[
    '1,234',
    'Total\n1,234',
  ]),
  CorpusCase('A number on a middle line updates', <Object>[
    'a\n1,234\nb',
    'a\n5,678\nb',
  ]),
  CorpusCase('Empty lines', <Object>['hello\n\nworld', 'hello\nworld']),
];
