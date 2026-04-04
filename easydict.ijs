require'data/dict'
coclass 'peasydict'
NB. Create easydict object. This defers creation of the underlying dictionary object and infers key/value types and shapes from the first put.
NB. Parameters (as for the data/dictionary addon) are given as a string with ; separating options.
NB. backingdict stores backing jdict. Before the first put, methods are placeholders. After the first put, they are inherited from the backing dict.
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
  params =: (#~ (~:&.|. *. a:~:])@:({."1)) params NB. Keep only most recent version of params and ensure no spurious empty param names.
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
  backingdict =: (dicttype,&<params) conew 'jdict'
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


NB. psym implements symbol tables; Old s: and s: inv correspond roughly to
NB. sym__obj and dat__obj. sym__obj takes boxed data and returns symbol
NB. indices, dat reverses this operation.
NB. Shape is preserved.
NB. Note: need backmap if values  to be adapted based on deleted symbols.
coclass'psym'
coinsert'jdictionary' NB. Inherit from jdictionary
create =: {{
  NB. create empty symbols dictionary
  create_jdict_ f. ('hash concurrent' ;< _2 ]\ 'keytype' ; 'boxed')
  del_int =: del f. NB. store standard del by symbol del
  del =: delsym f.  NB. ... and replace by delsym
  mut =: 10 T. 1 NB. mutex for updating. Counting so sym can recurse if insertion between check and not.
  data =: 0$a:   NB. init to no data.
  N =: 0         NB. next index to allocate; number of unique symbols seen (not stored)
  NB. hole management: keep empty ranges; no scattered indices since likely not much faster to keep separately. if implemented, get singles from ranges after merge in delsym, and add check in dat.
  DO =: 0        NB. offset: data ind = symind - offset
  DR =: 2 0$0    NB. deleted ranges starts&ends
  locktimeout =: 1 NB. 1 second timeout before sym gives up acquiring lock.
}}

NB. Get symbol number for boxed array of data; add to dict and store if not known yet. Like old s: but extended for any data.
NB. Data can be any (boxed) datatype, and boxed array can have any shape; shape is maintained for returned symbols.

NB. Design choices
NB. - as dicts don't allow references to data stored therein, sym & dat do the heavy lifting of storing all data in, and getting it from an array, respectively.
NB. - deletion is implemented in 2 ways:
NB.   + ranges of deleted indices are kept to mark data therein as invalid upon lookup; entries in the data noun are replaced by empty boxes to remove data stored.
NB.   + when the first index stored in data becomes invalid, the prefix of data that is invalidated is removed, and an index offset is incremented accordingly, so the data noun can be beheaded to remove empty leading boxes.
NB.   + this allows deletion, yet keeps symbol indices monotonically increasing
NB. - data noun stores boxed keys so any data can serve as symbol. Likely slower (boxed data incurs more hashing, boxing & unboxing) and fatter (extra pointers to be stored). Symbols could be altered to non-boxed storage, but this would obviate currently implemented deletion by ranges (as a row of fills would take up the same space as a used data record). One could change the way data is stored (see above) to directly remove rows, and compute indices into data from symbol indices based on deleted ranges, but this would be slower (index calculations likely ~ # deleted ranges and deletion in data noun leads to rewrite of all data after the deleted one).
NB. TODO CATEGORIZE: doing separate puts is 6.8 times slower than put in bulk (on 1e6 scalar (repeating) int keys & 2x3 float values)
NB. d=:easydict'hash'
NB. a=: 1e6 ?@$ 1000
NB. b=: 1e6 2 3 ?@$ 0
NB. timex'b put__d a'
NB. destroy__d''
NB. d=:easydict'hash'
NB. timex'b put__d"_1 a'

sym =: {{
  sh=. $ y
  NB. only look up unique. A bit against dictionary approach, but assuming
  NB. limited insertion at once. Otherwise impossible to know what value to
  NB. insert, unless done sequentially (which could be a solution though..., in
  NB. mutex, seq. insert syms if not has, add to data after loop block). TODO
  NB. benchmark both.
  id=. (~.i.])i.!.0~ ,y
  NB. if all unique data items found reshape those filled in.
  if. _1 -.@:e. rc =. _1 get un=.(~:id)#,y do. sh$id{rc return.end.
  if. -.11 T. mut;locktimeout do. NB. get lock on symbol table to perform insertions.
    try.
      if. +./has ny=.un #~ msk=._1=rc do. NB.  msk is 1 for new data; used to interleave new&old syms for return. if any new insertions before lock, redo sym, now having the lock ensures we'd have to retry only once.
        ns =. sym ny
      else.                     NB. No contention:
        (ns=. N+i.+/msk) put ny NB. The new data items ny get the next sequential numbers ns.
        N=:N+#ny                NB. update N
        data =: data, ny        NB. Remember new data
      end.
      13 T. mut                 NB. Release lock (regular)
    catch.                      NB. If error:
      13 T. mut                 NB.   release lock
      (}.@dberm dbsig dberr)''     NB.   reraise error
    end.
  else. 'failed to get lock'assert 0 end. NB. No lock after 1 second.
  sh $ id{ns (<($#:I.@,)msk)} rc NB. return reshaped, expanded, interleaved new/old syms.
}}

NB. Fetch the boxed string for symbol# y, s: inv.
NB. dat =: {"0 _ ".@'data'
NB.*[x] dat y get symbol data for indices y. x is optional default for deleted symbols; x will be boxed by dat before use.
dat =: {{
  if. -.11 T. mut;locktimeout do. try. NB. get lock
  NB. check inds in any range DR or < DO or >:N
  NB. TODO: Should add mutex lock here.
  msk=.(>:&N+.<&DO+.({.DR)&(>:/) +./@:*. ({:DR)&(<:/)) ,y
  ('Inexistent symbol indices: ',":msk#,y) dbsig^:(+./msk) 6
  res=.(DO-~y) {"0 _ data
  13 T. mut
  catch. NB. If error, release lock; re-raise error.
    13 T. mut
    (}.@dberm dbsig dberr)''
  end.
  res
  else. 'failed to get lock'assert 0 end. NB. No lock after 1 second. Adjust locktimeout if needed.
}} : {{ NB. dyadic case: fill in masked with default
  if. -.11 T. mut;locktimeout do. try. NB. get lock
  msk=.(>:&N+.<&DO+.({.DR)&(>:/) +./@:*. ({:DR)&(<:/)) ,y
  res=.($y) $ (<x) (I.msk)} (DO-~,y){data
  13 T. mut
  catch. NB. If error, release lock; re-raise error.
    13 T. mut
    (}.@dberm dbsig dberr)''
  end.
  res
  else. 'failed to get lock'assert 0 end. NB. No lock after 1 second. Adjust locktimeout if needed.
}}
NB.* del delete symbols; y is list of data or symbol indices. Deletion creates holes in data array, and corresponding indices will be invalidated for lookup using dat. 
delsym =: {{
  if. -.11 T. mut;locktimeout do. try. NB. get lock on symbol table to perform insertions.
      if. 0=L. y do.             NB. symbol indices given:
        'dd id' =. (dat y) ,&< y NB. look up data to remove.
        NB. TODO: dat should ideally have left arg to prevent error when deleting non-existing sym index congruent with del. However, must be unique. Could make empty as default, always existing symbol that cannot be deleted at index 0.
      else.
        'dd id' =. y ,&< _1 get y     NB. look up inds; _1 because should not error, but indicate miss in returned mask, as does standard del. _1 will never be in rem, because the corresponding dd will get 0 from del_int, as it was not in the dict. 
      end.
      NB. remove data at ids in rem
      rem =. id #~ dm =. del_int dd   NB. remove data to delete, turn inds into rem ranges
      data=: a: (rem-DO)} data NB. empty the boxes to be deleted
      NB. find new removed ranges
      remr =. (({.,{:);.1~1,}.~:1+}:)/:~rem 
      rg   =. /:~ remr,|:DR NB. all deleted ranges sorted
      NB. merge ranges:
      NB. correct I. for singleton ranges& extend right with 1 unit (adjacents should be 1); use modifier train to get II~ , II (AC, where C is CVC)
      adj  =. 1 e. (I.~ _1 1+]) (~([.,].)) NB. adjacent ranges
      mrg  =. <./`(>./)"1@:,.`,:@.(-.@adj) NB. merge x y if adjacent
      NB. Fold with initial as otherwise, ,: would be needed for every step; merge ranges from the back.
      rgm  =. (,:@{: ]F.:((mrg {.),}.@]) }:) rg
      NB. update offset if possible & adapt rgm accordingly
      if. DO = {.{.rgm do.
        newDO =. 1+{:{.rgm
        data  =: (newDO-DO)}.data
        DO    =: newDO
        rgm   =. }.rgm
      end.
      DR=:|:rgm
      13 T. mut
    catch.                                NB. If error, ensure lock is released; re-raise error.
      13 T. mut
      (}.@dberm dbsig dberr)''
    end.
    dm NB. return deleted mask for compatibility with del
  else. 'failed to get lock'assert 0 end. NB. No lock after 1 second. Adjust if needed.
}}
zap =: +/@del@".@'data' NB. when unload materialises: use that to get all keys; returns number of entries deleted.

NB. Export wrappers for EasyDicts and symbols to the z locale.

NB.*v easydict_z_: Create easydict. y: options as single, ;-separated string.
easydict_z_=:conew&'peasydict'
NB.*v symbols_z_: Create symbol table. Ignores y.
symbols_z_ =:''&conew@'psym'

NB. Future:
NB. TODO: grading & sorting. Benchmark 2 solutions: 1 doing lookup of sym in data, then sort by lookup selected data in dict
NB. TODO: MISSING: GRADE of given keys.
NB. grade takes symbols and returns them in ascending order
NB. grade =: ((~.i.])@(i.!.0)~ ([ { [: grad@dat ~:@[#]) ])
NB.   this would require reverse lookup; sym into keys for sorting; could be emulated having 2 dicts per symbol table though...
NB. TODO: persistence (once available unloading/loading working for dictionaries)

NB. see how far comparison holds. Should see how e.g. comparison is possible without getting key-data first.
NB. Then multi-sym table ops: joins/subtract/...
cocurrent'idict'
coinsert 'peasydict'
NB. pg for put-get: put increasing ints as values for new keys in y; get existing ones.
NB. keep simple: only list of values, no arbitrary shapes.
NB. if idict is empty, first put is interpreted as a single entire item (contrary to easydict, which treats it as a list of items)
pg =: {{
  if. 0 = ct=.count'' do. (put&,:~ 0+i.@#) y else.
    msk =. -. has y
    msk (# put~ ct + [: i. +/@[) y
  end.
  get y
}}
 

cocurrent 'pmem'
coinsert'peasydict'
NB. create pmem: args:#arg dicts,[boxResult,boxMonad/X,boxY]. [] optional, each is 1 if missing. #argdicts indicates whether x,y stored directly with results (0), separately in 1 (x and y) or 2 dictionaries (1 for x, one for y).
NB. If 1 argument dict used, boxing for x&y should be the same.
NB. combination 1 x 1 1 probably makes little sense, but 1 x 0 0 would avoid boxing, especially for same shape&type arguments. note that this would lead to x and y being combined, incurring any filling & type conversion as by ,: .
create =: {{
  y=. 4{.!.1 y NB. default 0 1 1 1
  dr =: conew&'peasydict' 'hash concurrent'
  assert. (1~:{.y) +. =/_2{.y NB. if. only 1 arg dict, both x&y must have same boxing status.
  '`br bx by'=: <^:(1&{y)`(<^:(2&{y))`(<^:(3&{y))
  NB. set verbs for put monadic & put dyadic
  if. 0={.y do.
    pm =: (a:,<@])^:(1{y) NB. box with a: if requested
    pd =: ,:`(,&<)@.(1{y) NB. laminate if not boxed, else ,&<
    dx =: dr [ dy=:dr     NB. for easy destroying; won't be used.
  else. 
    dy =: conew&'idict' 'hash concurrent'
    pm =. _1 , pg__dy@bx f. NB. monad args always in y, use bx, prepend _1 to allow storing monad&dyad in same dict if needed (slight overhead).
    if. 1={.y do.
      pd =: (pg__dy@bx , pg__dy@by) f. NB. 1 argdict, store in dy
      dx =: dr NB. not used; for easy destroying, dx must exist
    else. 
      pd =: (pg__dx@bx , pg__dy@by) f.
      dx =: conew&'idict' 'hash concurrent'
    end.
  end.
  M =: {{
  NB. TODO: somehow, if $: used, only end result is saved, not intermediates because $: then refers to u, i.e. without memorizing... would need to do complicated amend in atomic rep to apply M to $:'s, but not to entire verb, as that would lead to infinite recursion.
    e =. pm y NB. encode inputs
    if. count__dr '' do.
      if. has__dr e do.br^:_1 get__dr e else.   (e (][(put__dr~br)) u.) y end.
    else.
      (e (][(put__dr~boxin))&,: u.) y NB. ,: for easydict's first item
    end.
  :
    e =. x pd y NB. encode inputs
    if. count__dr '' do.
      if. has__dr e do.br^:_1 get__dr e else. x (e (][(put__dr~br)) u.) y end.
    else.
      x (e (][(put__dr~br))&,: u.) y NB. ,: for easydict's first item
    end.
  }}
  0 0$0
  }}
NB. no extra locking needed: all dict calls are already threadsafe. Worst case scenario: missing entry being needlesly repeated because another thread was already processing the same.
zap =: {{ NB. remove all results by deleting and recreating dict.
  for_o. ~.dr,dx,dy do. destroy__o'' end.
  create ''
}}
destroy=: {{
  for_o. ~.dr,dx,dy do. destroy__o'' end.
  codestroy y
}}

Note 'Comparison M. & pmem'
)
cocurrent'base'
boxdraw_j_ 1
tst=:{{
  metric =: 6!:2`(7!:2)@.('space'-:y)
  mettxt =: 'space: '"_^:('space'-:y)'time :'
  a=: conew&'pmem' x
  b=: conew&'pmem' x
  ao=: >:@]`(>:@])`(<:@[ $: 1:)`(<:@[ $: [ $: <:@]) @. (#.@(,&*))     "0
  am=: >:@]`(>:@])`(<:@[ $: 1:)`(<:@[ $: [ $: <:@]) @. (#.@(,&*))M.   "0 
  as=: >:@]`(>:@])`(<:@[ as 1:)`(<:@[ as [ as <:@]) @. (#.@(,&*))M__a "0 
  NB. ast=: >:@]`(>:@])`(<:@[ $: 1:)`(<:@[ $: [ $: <:@]) @. (#.@(,&*))M__b "0 
  NB. timex rather than timespacex as the latter first runs space, illing the cache so the timing is meaningless
  echo' orig     ',mettxt,":metric '1 2 3 ao >: 1 2 3,2 3 4,:4 5 6'
  echo' M.   1st ',mettxt,":metric '1 2 3 am >: 1 2 3,2 3 4,:4 5 6'
  echo' M.   2nd ',mettxt,":metric '1 2 3 am >: 1 2 3,2 3 4,:4 5 6'
  echo' pmem 1st ',mettxt,":metric '1 2 3 as >: 1 2 3,2 3 4,:4 5 6'
  echo' pmem 2nd ',mettxt,":metric '1 2 3 as >: 1 2 3,2 3 4,:4 5 6'
  NB. echo' pmem 1st ',mettxt,":metric '1 2 3 ast >: 1 2 3,2 3 4,:4 5 6'
  NB. echo' pmem 2nd ',mettxt,":metric '1 2 3 ast >: 1 2 3,2 3 4,:4 5 6'
  NB. echo' Stored results in a and b ',": (count__dr__a,count__dr__b)''
  destroy__a''
  NB. destroy__b''
  }}
