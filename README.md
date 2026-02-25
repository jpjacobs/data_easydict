# data\_easydict

This addon provides two classes:
- Easydict (peasydict): a convenient wrapper for the [data/dictionary](https://code.jsoftware.com/wiki/Vocabulary/Dictionaries_(addon)) addon.
An easydict object is a dictionary with the exact same methods as a standard jdictionary.
- Symbol tables (psym): A dictionary-based stand-in for J's global symbols (s:).

## Easydict
### Differences with data\_dictionary:

- conew/Create does not require keyshape, keytype, valueshape and valuetype. These properties are inferred from the items of the argument of put, when it first is called. For instance, if the '' put\_\_ed y is executed, with y=0.0+i. 2 3 4, a backing dictionary kept in the easydict object is created with keytype floating and and key shape 3 4, and the two keys are put into this dictionary, and without values.
- Before the first put, some dictionary methods are defined to have sensible defaults (e.g. has and del is 0"\_1, count is 0:) and others are defined to error upon use (as the backing dictionary does not exist yet).
- Options are passed to conew in a single ;-separated literal, e.g. easydict 'tree concurrent;occupancy 0.3'
- "put" used monadically is equivalent to '' put y, i.e. when put is used monadically, values are omitted.
- easydict\_z\_ defined as convenient alias to conew&'peasydict'

### Limitations
Not supported (yet):

- keyhash and keycompare options.

### Future:

- Operations on entirety or parts of dictionary
- Operations between dictionaries (joins, merges, operations between matching keys).

### Usage Example

       install'github:jpjacobs/data\_easydict
       load'data/easydict'
       d =: eaydict 'tree concurrent'
       count__d ''
    0
       has__d 1 2 3
    0 0 0
       min__d ''
    |easydict not active; put first entry before use: min__d
    |       min__d''
       1 2 3 put__d 3 4$'abcdef'
       ([: range__d min__d ,:&(>@{.) max__d)''
    ┌────┬─────┐
    │abcd│1 3 2│
    │cdef│     │
    │efab│     │
    └────┴─────┘

## Symbol tables
Symbol table stores in a dict the data as keys, and symbol indices as values. Data is kept separately for reverse-indexing into using symbols as well.
Any boxed data may be stored (in contrast with original s:, only storing literals).

### Usage example

       load'data/easydict'
       st=: symbols''
       sym__st <;._1 ' foo bar a b c'
    0 1 2 3 4
       sym__st 3 3$<;._1 ' foo bar a b c' NB. Shape maintained.
    0 1 2
    3 4 0
    1 2 3
       sym__st <"+ i. 2 3 4 NB. any data stored.
     5  6  7  8
     9 10 11 12
    13 14 15 16

    17 18 19 20
    21 22 23 24
    25 26 27 28
       dat__st 3 4 22 23 NB. reverse lookup by symbol index.
    ┌─┬─┬──┬──┐
    │b│c│17│18│
    └─┴─┴──┴──┘
       min__st'' NB. dictionary methods inherited.
    ┌───┬─┐
    │┌─┐│5│
    ││0││ │
    │└─┘│ │
    └───┴─┘
       count__st''
    29
