# data\_easydict

This addon provides an easy wrapper for data/dictionary available at https://code.jsoftware.com/wiki/Vocabulary/Dictionaries_(addon).
The created object is treated exactly like a standard jdictionary.

Differences with data\_dictionary:

- Create does not require keyshape, keytype, valueshape and valuetype. These are inferred when put is called for the first time, from the items of put. For instance, if the '' put\_\_ed y is executed, with y=0.0+i. 2 3 4, a backing dictionary kept in the easydict object is created with keytype floating and and key shape 3 4, and the two keys are put into this dictionary.

- Options are passed to conew in a single ;-separated literal, e.g. 'tree concurrent;occupancy 0.3' conew 'peasydict'.

- put used monadically is equivalent to '' put y, i.e. when put is used monadically, values are omitted.

Future:

- Operations on entirety or parts of dictionary
- Operations between dictionaries (joins, merges, operations between matching keys).
