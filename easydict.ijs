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
    (prefix , 'min' , suffix) =: err f.
    (prefix , 'max' , suffix) =: err f.
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
