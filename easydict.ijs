require'data/dict' 
coclass 'peasydict'
NB. Create easydict object. This defers creation of the underlying dictionary object and infers key/value types and shapes from the first put.
NB. Parameters (as for the data/dictionary addon) are given as a string with ; separating options.
NB. backingdict stores backing jdict. Before the first put, methods are placeholders. After the first put, they are inherited from the backing dict.
NB. Currently not supported: params taking gerunds as values (keycompare, keyhash).

NB. TODO
NB. - Probably should put mutex on put verb to avoid races.
NB. - Persistence (jfiles?)
issym =: 0                               NB. set not-symbol per default.
create =: {{)m
  origparams =: y
  par =. (<,';') cut ;: y NB. split argument string in chunks by ; after & convert to int where possible.
  dicttype =: ;: inv 0 {:: par                    NB. boxed dict type
  params   =: ([ [^:(_-:]) _&".) L: 0  > }. par   NB. Assumes all keyword/value params are paired, and valid J words.
  if. (#params)>namei=.'name' i.~ {."1 params do. NB. set name if option is present.
    name=: namei {:: {:"1 params
  else.
    name=:'' 
  end.
  NB. replace all shorter parameters by long ones; in order for dedupe to work properly afterwards.
  params =: rplc&(<;._1 ' kt keytype ks keyshape vt valuetype vs valueshape') L: 0 params
  NB. if all key/val types&shapes defined, just create the dictionary
  if. *./ ({."1 params) e.~ <;._1 ' keytype keyshape valuetype valueshape' do.
    createdict''
  else. NB. lazy dictionary; infer key/value type/shape from first insert.
  name =. ,&'__'^:('_' ~: {:!.'_') name  NB. if name is not empty and doesn't end with _, append __ Note: name__ is equivalent to name_base_ .

  ('put', name) =: ''&$: : {{ NB. Place-holder for lazy creation of dictionary.
  NB. Set key type shape from first insert keys (and values if provided)
  NB. Note 0: This overwrites any previously set key/val type/shape.
  NB.     Alternatively: check for compliance with ones that did get set upon creation.
  NB. Note 1: This addon chooses to use items of both keys and values as items in the dictionary. Alternatively, one could consider both a single item
  NB.    Either case, if not specified explicitly, one or the other behaviour should be chosen.
  'y must be non-empty' assert y -.@:-: ''
  params =: params,('keytype';'keyshape'),. (3!:0 ; }.@$) y
  if. x-:'' do.
    if. -. issym do.
      params =: params,('valuetype';'valueshape'),. 4 ; 0          NB. No values provided, set default type/shape
    end.
  else.
    params =: params,('valuetype';'valueshape'),.(3!:0 ; }.@$) x NB. Takes vt and vs from provided values
  end.
  params =: (#~ (~:&.|. *. a:~:])@:({."1)) params NB. Keep only most recent version of params and ensure no spurious empty param names.
  createdict''
  try.  NB. try initial put, if fails, restore state, and rethrow error
    if. issym do. put__backingdict y else. x put__backingdict y end.
  catch.
    'emsg eno'=.(dberm;dberr)''  NB. save the error message for the error
    destroy__backingdict '' NB. prevent leaking dicts.
    create origparams       NB. recreate original object 
    emsg dbsig eno
  end.
}}

  NB. Other method, for all dict types.
  ('get' , name)   =: (err =. 'easydict not active; put first entry before use'&assert@:0:) f. NB. Others just error.
  ('has' , name)   =: 0"_1 NB. Sensible defaults for del/has/count for empty dict.
  ('count' , name) =: 0:   NB. no items yet
  ('items' , name) =: err f. NB. (,~ a:)"_ empty boxes could make sense here, but would assume keys and values, while not always true ... alternatively  single box if vs-:0 .
  if. -. issym do.
    ('del' , name)   =: 0"_1 NB. any deletion "works", on items.
  end.
  if. 'tree' e. >dicttype do. NB. methods for tree dicts only
    ('mget' , name) =: err f. NB. Stock gives domain error...
    ('min' , name) =: 13!:8@6 NB. stock does index error instead.
    ('max' , name) =: 13!:8@6 
    ('after' , name) =: err f.
    ('since' , name) =: err f.
    ('before' , name) =: err f.
    ('until' , name) =: err f.
    ('range' , name) =: err f.
    ('audittree', name) =: err f. NB. not official interface anyhow...
  else. NB. methods for hash dicts only (currently empty, for future use).
  end.
end.
EMPTY
}}
  
createdict =: {{       NB. split off actual dictionary noun creation.
  backingdict =: (dicttype,&<params) conew issym {:: ;: 'jdict jsymbol'
  NB. Erase all verbs defined before, so ones of parent dict are called.
  erase (],name"_)&.>&.;: 'get del has count items mget min max after since before until range audittree'
  if. issym do. 
    ('put',name) =: put__backingdict NB. give put a monadic meaning of omitted values.
  else.
    ('put',name) =: ''&$: : put__backingdict NB. give put a monadic meaning of omitted values.
  end.
  coinsert backingdict NB. make available all verbs defined in created backing dict.
  EMPTY
}}

destroy =: {{
  if. 0<:nc <'backingdict' do. destroy__backingdict'' end. NB. destroy backing dict first, if existing.
  codestroy y  NB. destroy the locale, freeing everything
}}

NB. psym implements symbol tables; Old s: and s: inv correspond roughly to
NB. sym__obj and dat__obj. sym__obj takes boxed data and returns symbol
NB. indices, dat reverses this operation.
NB. Shape is preserved.
NB. Note: need backmap if values  to be adapted based on deleted symbols.
coclass'psym'
coinsert'peasydict' NB. Inherit from from peasydict
issym =: 1 NB. set symbol; then do whatever easydict does.
sym =: (get [ put) NB. now puts all inputs; no inverse, because it doesn't work well with classes...
NB. Sorting: if given ints, sorts them according to lexicographic order of corresponding data; if given data, sorts them according to adding order
NB.   data not in symbol dictionary appear at the beginning for asc and end for desc
asc   =: (/: get)  NB. sort up
desc  =: (\: get)  NB. sort down
create =: (create_peasydict_ f.)@:(('hash'&,)^:('hash' -.@:(+./)@:E. ])) NB. TODO stress test
createdict =: createdict_peasydict_ f. NB. Required so createdict runs in symbol locale,so erase erases names from sym object, not in parent class.

NB.*v easydict_z_: Create easydict. y: options as single, ;-separated string.
easydict_z_=:conew&'peasydict'
NB.*v symbols_z_: Create symbol table. Ignores y.
symbols_z_ =:''&conew@'psym'

NB. Future:
NB. TODO: persistence (once available unloading/loading working for dictionaries)
