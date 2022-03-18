::
::::  auth-id.hoon
::
::      %gall agent to authenticate a ship for Urbit Visor.
::
::    The basic architecture is that Visor requests a website running the agent
::    to produce a token and wait for a DM containing the token from the
::    authenticating ship.
::
/-  graph-store
/+  server, default-agent, dbug, graph-store, graph-utils
%-  agent:dbug
^-  agent:gall
=|  key=@uv
|_  =bowl:gall
+*  this      .
    card  card:agent:gall
    default   ~(. (default-agent this %|) bowl)
    gu        ~(. graph-utils bowl)
::
++  on-init
  ^-  (quip card _this)
  ~&  >  '%auth-id initialized successfully'
  =.  key  `@uv`(end 7 eny.bowl)
  ~&  >>  "Your api key is {<key>}"
  :_  this
  :~  [%pass /bind %arvo %e %connect [~ /'~initiateAuth'] %auth-id]
  ==
++  on-save   !>(key)
++  on-load
  |=  old-key=vase   
  =.  key  !<(@uv old-key)
  `this
++  on-poke   
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^
  ?+  mark  `this
  %noun
    =/  arg  !<(* vase)
    ?+  arg  `this
  [%approve @t]
    =/  c=card  [%pass /cors-approve %arvo %e %approve-origin +.arg]
    :_  this
    ~[c]
  %cycle-key
    =.  key  `@uv`(end 7 eny.bowl)
    ~&  >  "Your new api key is {<key>}"
   `this
  %print-key
    ~&  >  "Your api key is {<key>}"
    `this
  ==
    %handle-http-request
      =+  !<([id=@ta =inbound-request:eyre] vase)
      ?>  =(url.request.inbound-request '/~initiateAuth')
      =/  valid-key=?  (validate-key request.inbound-request)
      ?.  valid-key  ~&  >>>  "invalid api-key"
      (bail id 'invalid-api-key')
      ::
      :: Inputs:
      ::   Urbit ship to authenticate @p: String
      ::
      :: Outputs:
      ::   Auth code: String
      ::   Source ship @p (our): String
      ::   Target ship @p: String
      ::
      :: Side Effects: none
      ::
      :: Description:
      ::   This generates a random @p encoded auth code, sends it as a
      ::   graph-store DM to the ship given in the input, and returns 
      ::   the auth-code as an HTTP response for the requester to save.
      ::
      ~&  >  "%auth-id request hit /~initiateAuth"
      =/  target=(unit @p)  (parse-target inbound-request)
      ?~  target  (bail id 'invalid ship name')
      =/  token  `@p`(end 6 eny.bowl)
      =/  dm-poke=card  (send-dm u.target token)
      =/  http-response=(list card)
        %+  give-simple-payload:app:server  id
        (handle-auth-request u.target token)
      :_  this
      (snoc http-response dm-poke)
  ==
  ++  validate-key
    |=  r=request:http  ^-  ?
    =/  header=header-list:http  %+  skim  header-list.r
    |=  [key=@t value=@t]
    =(key 'auth')
    ?~  header  %|  
    =/  format  (slaw %uv value.i.header)
    ?~  format  %|  =(u.format key)
  ++  parse-target
    |=  [ir=inbound-request:eyre]
    ^-  (unit @p)
    ?.  ?=(%'POST' method.request.ir)  ~
    (slaw %p +511:ir)
  ++  send-dm
    |=  [target=@p auth-code=@p]
    ^-  card
    =/  t  "Your urbit auth code is \0a {<auth-code>}"
    =/  contents  
    :~
    [%text text=(crip t)]
    ==
    =/  update  (build-dm:gu target contents)
    [%pass /send-auth-code %agent [our.bowl %dm-hook] %poke %graph-update-3 !>(update)]
  ++  handle-auth-request
    |=  [target=@p token=@p]
    ^-  simple-payload:http
    =,  enjs:format
    %-  json-response:gen:server
    %-  pairs
    :~
      [%target [%s (scot %p target)]]
      [%token [%s (scot %p token)]]
    ==
  ++  error-response
    |=  error=@t
    ^-  simple-payload:http
    =,  enjs:format
    %-  json-response:gen:server
    %+  frond  
    %error  s+error
  ++  bail
    |=  [id=@ta error=@t]
    ^-  (quip card _this)
    :_  this
    %+  give-simple-payload:app:server  id
    (error-response error)
  --
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  `this
++  on-watch
  |=  =path
  `this
++  on-leave  on-leave:default
++  on-peek   on-peek:default
++  on-agent  on-agent:default
++  on-fail   on-fail:default
--