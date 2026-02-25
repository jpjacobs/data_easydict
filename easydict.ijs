require'data/dictionary'

coclass 'peasydict'


NB. Create easydict object. This defers creation of the underlying dictionary object and infers key/value types and shapes from the first put.
NB. Parameters (as for the data/dictionary addon) are given as a string with ; separating options.
NB. backingdict stores backing jdictionary. Before the first put, methods are placeholders. After the first put, they are inherited from the backing dict.
NB. Currently not supported: params taking gerunds as values (keycompare, keyhash).

create =: {{)m
  par =. (<,';') cut ;: y           NB. split argument string in chunks by ; after 
  dicttype  =: ;: inv 0 {:: par            NB. boxed dict type
  params =: (]`[@.(_-:])&.> _&".&.>) > }. par NB. Assumes all keyword/value params are paired, and valid J words.
  if. (#params)>namei=.'name' i. {."1 params do. 
    name=: namei {:: {:"1 params
  else.
    name=:'' 
  end.
  NB. if all key/val types&shapes defined, just create the dictionary
  if. *./ ({."1 params) e. <;._1 ' keytype keyshape valuetype valueshape' do.
    createdict''
  else. NB. lazy dictionary; infer key/value type/shape from first insert.
  if. name -: '' do. prefix =. suffix =. '' else. 'prefix suffix' =. (,{:)&.>/\. split_name name end.

  (prefix , 'put' , suffix) =: ''&$: : {{ NB. Place-holder for lazy creation of dictionary.
  NB. Set key type shape from first insert keys (and values if provided)
  NB. Note 0: This overwrites any previously set key/val type/shape.
  NB.     Alternatively: check for compliance with ones that did get set upon creation.
  NB. Note 1: This addon chooses to use items of both keys and values as items in the dictionary. Alternatively, one could consider both a single item
  NB.    Either case, if not specified explicitly, one or the other behaviour should be chosen.
  'y must be non-empty' assert y -.@:-: ''
  params =: params,('keytype';'keyshape'),. (3!:0 ; }.@$) y
  if. x-:'' do.
    params =: params,('valuetype';'valueshape'),. 4 ; 0     NB. No values provided, set default type/shape
  else.
    params =: params,('valuetype';'valueshape'),.(3!:0 ; }.@$) x
  end.
  params =: (#~ ~:&.|.@:({."1)) params NB. Keep only most recent version of params.
  createdict''
  x put__backingdict y
}}
  NB. Other methods
  (prefix , 'get' , suffix)   =: (err =. 'easydict not active; put first entry before use'&assert@:0:) f. NB. Others just error.
  (prefix , 'del' , suffix)   =: 0"_1 NB. Sensible defaults for del/has/count for empty dict.
  (prefix , 'has' , suffix)   =: 0"_1 
  (prefix , 'count' , suffix) =: 0:
  if. 'tree' e. >dicttype do.
    (prefix , 'mget' , suffix) =: err f.
    (prefix , 'min' , suffix) =: 13!:8@6 NB. stock does index error instead.
    (prefix , 'max' , suffix) =: 13!:8@6
    (prefix , 'after' , suffix) =: err f.
    (prefix , 'since' , suffix) =: err f.
    (prefix , 'before' , suffix) =: err f.
    (prefix , 'until' , suffix) =: err f.
    (prefix , 'range' , suffix) =: err f.
  end. 
end.
EMPTY
}}
  
createdict =: {{       NB. split off actual dictionary noun creation.
  backingdict =: (dicttype,&<params) conew 'jdictionary'
  if. name -: '' do. prefix =. suffix =. '' else. 'prefix suffix' =. (,{:)&.>/\. split_name name end.
  NB. Erase all verbs defined before, so ones of parent dict are called.
  erase (prefix,],suffix"_)&.>&.;: 'get del has count mget min max after since before until range'
  (prefix,'put',suffix) =: ''&$: : put__backingdict NB. give put a monadic meaning of omitted values.
  coinsert backingdict NB. make available all verbs defined in created backing dict.
  EMPTY
}}

destroy =: {{
  if. 0<:nc <'backingdict' do. destroy__backingdict'' end. NB. destroy backing dict first, if existing.
  codestroy y  NB. destroy the locale, freeing everything
}}

NB. y is string representing a name with possibly specified locale. Returns two boxes: name ; suffix with locale.
NB. Right part of hook.
NB. If '_' is the last character of y then the name has explicitly specified locale, so get the indexes of '_'.
NB. Left part of hook.
NB. Use the indexes to split the name or if the number of indexes is less than 2 then suppose name is from base.
NB. Note that number of indexes may be smaller then number of '_' e.g. 0 when condition from right part of the hook was false.
split_name =: ('__' ,~&< [)`(({. ,&< }.)~ _2&{)@.(2 <: #@])  ''"_`([: I. '_'&=)@.('_' -: {:)

NB. wrapper for creating EasyDict in z locale.
NB. Provide options as single, ;-separated string.
easydict_z_=:conew&'peasydict'

coclass'psym'
coinsert'jdictionary'
create =: {{
  NB. create empty symbols table
  create_jdictionary_ f. ('tree concurrent' ;< _2 ]\ 'keytype' ; 'boxed')
  mut =: 10 T. 0 NB. mutex for updating.
  data =: 0$a:    NB. init to no data.
}}
NB. Get symbol number for boxed data; add to dict and store if not known yet. Like s: but extended for any data. inverse looks up the data of symbol numbers.
sym =: {{
  sh=. $ y
  id=. (~.i.])i.!.0~ ,y NB. only look up unique. A bit against dictionary approach, but assuming limited insertion at once. Otherwise impossible to know what value to insert, unless done sequentially (which could be a solution though..., in mutex, seq. insert syms if not has, add to data after loop block). TODO benchmark both.
NB. mask of found syms; if any not found, add, else ret.
if. _1 -.@:e. rc =. _1 get un=.(~:id)#,y do. sh$rc return.end.  NB. If all already present, return its symbol#
  if. -.11 T. mut;1 do.
    try.
      (ns=. (#data)+i.+/msk) put ny=.un #~ msk=._1=rc  NB. The new data items ny get the next sequential numbers ns. msk is 1 for new data; used to interleave new&old syms for return.
      data =: data, ny  NB. remember the new string
      13 T. mut NB. release lock.
    catch. NB. ensure lock is released; re-raise error.
      13 T. mut
      (dberm dbsig dberr)''
    end.
  else. 'failed to get lock'assert 0 end.
  sh $ id{ns (<($#:I.@,)msk)} rc NB. return reshaped, expanded, interleaved new/old syms.
}}
NB. Fetch the boxed string for symbol# y, s: inv.
dat =: {"0 _ ".@'data'
NB. TODO: ordering & sorting. Benchmark 2 solutions: 1 doing lookup of sym in data, then sort by lookup selected data in dict
NB. TODO: MISSING: GRADE of given keys.
NB. grade takes symbols and returns them in ascending order
grade =: ((~.i.])@(i.!.0)~ ([ { [: grad@dat ~:@[#]) ])
NB.   this would require reverse lookup; sym into keys for sorting; could be emulated having 2 dicts per symbol table though...
NB. TODO: persistence (once available unloading/loading working for dictionaries)

NB. see how far comparison holds. Should see how e.g. comparison is possible without getting key-data first.
NB. Then multi-sym table ops: joins/subtract/...
