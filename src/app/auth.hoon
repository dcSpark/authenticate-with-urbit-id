/-  *auth-action
/+  default-agent, dbug
|%
+$  versioned-state
    $%  state-0
        state-1
    ==
+$  state-0  [%0 counter=@]
+$  state-1  [%1 tokens=(map @p @uw)]
+$  card  card:agent:gall
--
%-  agent:dbug
=|  state-1
=*  state  -
^-  agent:gall
=<
|_  bol=bowl:gall
+*  this     .
    default  ~(. (default-agent this %|) bol)
    main     ~(. +> bol)
::
++  on-init
  ^-  (quip card _this)
  ~&  >  '%auth initialized successfully'
  =.  state  [%1 *(map @p @uw)]
  `this
++  on-save
  ^-  vase
  !>(state)
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  ~&  >  'auth recompiled successfully'
  =/  prev  !<(versioned-state old-state)
  ?-  -.prev
    %0
    ~&  >>>  '%0'
    `this(state [%1 *(map @p @uw)])
    ::
    %1
    ~&  >>>  '%1'
    `this(state prev)
  ==
:: handles any calls from outside processes that aren't subscriptions,
:: i.e. one-time actions
++  on-poke
  |=  [=mark =vase]
    ^-  (quip card _this)
    ?+    mark  (on-poke:default mark vase)
        %noun
      ?+    q.vase  (on-poke:default mark vase)
          %print-state
        ~&  >>  state
        ~&  >>>  bol  `this
        ::
          %print-subs
        ~&  >>  &2.bol  `this
        ::
          %poke-self
        ?>  (team:title our.bol src.bol)
        :_  this
        ~[[%pass /poke-wire %agent [our.bol %auth] %poke %noun !>([%receive-poke 2])]]
        ::
        ::
          [%receive-poke @]
          ~&  >  "got poked from {<src.bol>} with val: {<+.q.vase>}"  `this
        ::
          [%receive-token *]
          :: presumptively received a unit, should check this
          ~&  >  "got poked from {<src.bol>} with token: {<+>.q.vase>}"  `this
      ==
      ::
        %auth-token
        ~&  >>>  !<(action vase)
        =^  cards  state
        (handle-action:main !<(action vase))
        [cards this]
    ==
::
:: receives incoming subscription requests from other processes
++  on-watch  on-watch:default
:: receives notifications that another process is unsubscribing
++  on-leave  on-leave:default
++  on-peek   on-peek:default
:: receives responses when we call another Gall agent's on-poke or on-watch
++  on-agent  on-agent:default
:: receives responses from Arvo vanes (such as a list of files if we ask
:: Clay to list a directory's contents)
++  on-arvo   on-arvo:default
:: if a crash happens in any arm except on-poke or on-watch
++  on-fail   on-fail:default
--
|_  bol=bowl:gall
++  default-insecure-token  4  :: 4 bytes
++  default-secure-token   64  :: 64 bytes
++  generate-token
  |=  len=@ud   :: length in bytes
  ^-  @uw
  `@uw`(end [len 1] eny.bol)
::
::  If destination desk doesn't exist, need a %init merge.  If this is
::  its first revision, it probably doesn't have a mergebase yet, so
::  use %take-that.
::
++  get-germ
  |=  =desk
  =+  .^(=cass:clay %cw /(scot %p our.bol)/[desk]/(scot %da now.bol))
  ?-  ud.cass
    %0  %init
    %1  %take-that
    *   %mate
  ==
++  handle-action
  |=  =action
  ^-  (quip card _state)
  ?-    -.action
    ::
    :: Update internal map of ships to current tokens
      %generate-token
    =/  token  (generate-token default-insecure-token)
    =.  tokens.state  (~(gas by tokens.state) ~[[target.action token]])
    :_  state
    ~[[%give %fact ~[/tokens] [%atom !>(tokens.state)]]]
    ::
    :: Replace current token for a given ship, functionally the same
      %reset-token
    =/  token  (generate-token default-insecure-token)
    =.  tokens.state  (~(gas by tokens.state) ~[[target.action token]])
    :_  state
    ~[[%give %fact ~[/tokens] [%atom !>(tokens.state)]]]
    ::
    :: Send a token to a remote ship
      %send-token
    :_  state
    ~[[%pass /poke-wire %agent [target.action %auth] %poke %noun !>([%receive-token (~(get by tokens.state) target.action)])]]
    ::
    :: Write the token to a new Clay desk for more permanent storage
    ::
    :: TODO
    :: %write-token
    :: Need to do two things:  check if desk exists
    ::=/  desk  `@tas`(scot %p target.action)
    ::=/  =germ  (get-germ desk)
    :: and then write the token in some form TODO should hash/salt or something
    ::=/  pax  "token"
    :::_  state
    ::~[[%pass (weld /write pax) %arvo %c %merg desk /=== germ]]
  ==
::
--
