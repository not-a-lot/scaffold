xquery version "1.0";
(: --------------------------------------
   Oppidoc Business Application Development Framework

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Utilities

   November 2016 - (c) Copyright 2016 Oppidoc SARL. All Rights Reserved.
   ----------------------------------------------- :)

module namespace misc = "http://oppidoc.com/ns/cctracker/misc";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace mail = "http://exist-db.org/xquery/mail";
import module namespace access = "http://oppidoc.com/oppidum/access" at "access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "display.xqm", "../app/display.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../oppidum/lib/compat.xqm";

(: ======================================================================
   High-level function to dereference one or more reference elements
   Returns a new element tag containing all unreferenced refs
   Dereferences picking up a selectors list from global-information
   The list name is derived from conventions on the element's name
   ======================================================================
:)
declare function misc:gen_display_name( $refs as element()*, $tag as xs:string ) as element()? {
  if ($refs) then
    let $driver := local-name($refs[1])
    let $root := substring-before($driver, 'Ref')
    let $type :=
      if (ends-with($root, 'y')) then
        replace($root, 'y$', 'ies')
      else
        concat($root, 's')
    return
      let $label := display:gen-name-for($type, $refs, 'en')
      return
        element { $tag } { $label }
  else
    ()
};

declare function local:gen_display_attribute( $refs as element()* ) as attribute()? {
  if ($refs) then
    let $driver := local-name($refs[1])
    let $root := if (ends-with($driver, 'Ref')) then substring-before($driver, 'Ref') else $driver
    let $type :=
      if (ends-with($root, 'y')) then
        replace($root, 'y$', 'ies')
      else
        concat($root, 's')
    return
      let $label := display:gen-name-for($type, $refs, 'en')
      return
        if ($label) then
          attribute { '_Display' } { $label }
        else
          ()
  else
    ()
};

(: ======================================================================
   Generates _Display attributes to unreference encoded values

   FIXME: the pluralization rule is border-line since we have not yet clear
   conventions to detect this kind of field, maybe we could explicitly
   test plural fields (actually CallTopics, TargetedMarkets ?)

   TODO:
   - add $lang parameter
   ======================================================================
:)
declare function misc:unreference( $nodes as item()* ) as item()* {
  for $node in $nodes
  return
    typeswitch($node)
      case text()
        return $node
      case attribute()
        return $node
      case element()
        return
          let $tag := local-name($node)
          return
            if (ends-with($tag, 's') and (count($node/*) > 0) and
                (every $c in $node/* satisfies (ends-with(local-name($c), 'Ref') and not(ends-with(local-name($c), 'ScaleRef'))))) then
              element { $tag }
                {(
                local:gen_display_attribute($node/*),
                $node/*
                )}
            else if (ends-with($tag, 'Ref') or ($tag eq 'Country')) then
              element { $tag }
                {(
                local:gen_display_attribute($node),
                $node/text()
                )}
            else if ($tag eq 'Date') then
              misc:unreference-date($node)
            else
              element { $tag }
                { misc:unreference($node/(attribute()|node())) }
      default
        return $node
};

declare function misc:unreference( $ref as element()?, $tag as xs:string, $lang as xs:string ) as element() {
  element { $tag }
    {(
    local:gen_display_attribute($ref),
    $ref/text()
    )}
};

declare function misc:unreference-date( $node as element()? ) as element()? {
  if ($node) then
    element { local-name($node) }
      {
      let $value := string($node/text())
      return
          (
          attribute { '_Display' } {
            if (string-length($value) > 10) then (: full date time skips time :)
              display:gen-display-date(substring($value, 1, 10), 'en')
            else
              display:gen-display-date($value, 'en')
          },
          $value
          )
      }
  else
    ()
};

(: ======================================================================
   Returns en element named $tag containing the current date
   ======================================================================
:)
declare function misc:gen-current-date( $tag as xs:string ) as element() {
  let $value := current-dateTime()
  return
    element { $tag } {
      (
      attribute { '_Display' } { display:gen-display-date(substring(string($value), 1, 10), 'en') },
      $value
      )
    }
};

(: ======================================================================
   Returns the name of the current user as First name Last name or falls back to user login
   ======================================================================
:)
declare function misc:gen-current-person-name() as xs:string {
  let $uid := access:get-current-person-id()
  let $name := display:gen-person-name($uid, 'en')
  return
    if ($name) then $name else oppidum:get-current-user()
};

(: ======================================================================
   Returns en element named $tag containing the name of the current user
   as First name Last name
   ======================================================================
:)
declare function misc:gen-current-person-name( $tag as xs:string ) as element() {
  element { $tag } {
    misc:gen-current-person-name()
  }
};

(: ======================================================================
   Returns en element named $tag containing a reference to the current user id
   or the exist login otherwise (typically admin)
   ======================================================================
:)
declare function misc:gen-current-person-id( $tag as xs:string ) as element() {
  let $uid := access:get-current-person-id()
  return
    element { $tag } {
      if ($uid) then
        $uid
      else
        oppidum:get-current-user()
    }
};

(: ======================================================================
   FIXME: defensive
   ======================================================================
:)
declare function misc:unreference-person( $person as element()?, $lang as xs:string ) as element()* {
  if ($person) then
    let $ref := $person/text()
    return
      element { node-name($person) }
        {(
        attribute { '_Display' } { display:gen-person-name($ref, $lang) },
        $ref
        )}
  else
    ()
};

(: ======================================================================
   FIXME: defensive
   ======================================================================
:)
declare function misc:unreference-person( $person as element()?, $tag as xs:string, $lang as xs:string ) as element()* {
  if ($person) then
    let $ref := $person/text()
    return
      element { $tag }
        {(
        attribute { '_Display' } { display:gen-person-name($ref, $lang) },
        $ref
        )}
  else
    ()
};

(: ======================================================================
   Returns a deep copy of the nodes sequence removing blacklisted node names
   ======================================================================
:)
declare function misc:filter( $nodes as item()*, $blacklist as xs:string* ) as item()* {
  for $node in $nodes
  return
    typeswitch($node)
      case text()
        return $node
      case attribute()
        return $node
      case element()
        return
          if (local-name($node) = $blacklist) then
            ()
          else
            element { node-name($node) }
              { misc:filter($node/(attribute()|node()), $blacklist) }
      default
        return $node
};

(: ======================================================================
   Returns node set containing only nodes in node set with textual
   content (note: attribute is not enough to qualify node for inclusion)
   ====================================================================== 
:)
declare function misc:prune( $nodes as item()* ) as item()* {
  for $node in $nodes
  return
    typeswitch($node)
      case text()
        return $node
      case attribute()
        return $node
      case element()
        return
          if (empty($node/*) and normalize-space($node) ne '') then
            $node
          else if (some $n in $node//* satisfies normalize-space($n) ne '') then
            let $tag := local-name($node)
            return
              element { $tag }
                { misc:prune($node/(attribute() | node())) }
          else
            ()
      default
        return $node
};

(: ======================================================================
   Renames a terminal element with tag name
   Does not preserve attribute(s)
   ======================================================================
:)
declare function misc:rename-element( $tag as xs:string, $e as element()? ) as element()? {
  if ($e) then
    element { $tag } {
      $e/text()
    }
  else
    ()
};

(: ======================================================================
   Replace legacy content with new content if it exists otherwise
   inserts new content into parent and returns success message
   Note that if no new content is provided returns success w/o updating legacy content
   ======================================================================
:)
declare function misc:save-content( $parent as element(), $legacy as element()?, $new as element()? ) as element()* {
  if ($new) then
    if ($legacy) then (
      update replace $legacy with $new,
      oppidum:throw-message('ACTION-UPDATE-SUCCESS', ())
    ) else (
      update insert $new into $parent,
      oppidum:throw-message('ACTION-CREATE-SUCCESS', ())
    )
  else
    oppidum:throw-message('ACTION-UPDATE-SUCCESS', ())
};

(: ======================================================================
   Stub function to call misc:save-content and if present and if success
   insert a forward element into the sucess response
   ======================================================================
:)
declare function misc:save-content( $parent as element(), $legacy as element()?, $new as element()?, $forward as element()? ) as element()* {
  let $res := misc:save-content($parent, $legacy, $new)
  return
    if ($forward) then
      if (local-name($res) eq 'success') then
        <success>
         {
           $res/*,
           $forward
         }
        </success>
      else
        $res
    else
      $res
};

(: ======================================================================
   Quick and Dirty XML diff between two sequencess which are supposed
   to contains the same elements without doublons
   Simply compare string content
   ======================================================================
:)
declare function misc:same-filter( $src as item()*, $dest as item()*, $blacklist as xs:string* )  {
  let $cur := $src[local-name(.) != $blacklist]
  let $base := $dest[local-name(.) != $blacklist]
  return
    every $n in $cur satisfies (string($n) = string($base[local-name(.) = local-name($n)]))

};

(: ======================================================================
   Generates a person email from a reference to a person or the empty string
   See also display:gen-person-email
   ======================================================================
:)
declare function misc:gen-person-email( $ref as xs:string? ) as xs:string? {
  if ($ref) then
    fn:doc($globals:persons-uri)/Persons/Person[Id = $ref]/Contacts/Email/text()
  else
    ''
};

(: ======================================================================
   Returns file extension from filename normalized to lower case
   FIXME: the request API does not allow to directly get file mime type,
   hence we try to deduce it from the file name
   ======================================================================
:)
declare function misc:get-extension( $filename as xs:string ) as xs:string
{
  let $fn := normalize-space($filename)
  let $unparsed-extension := lower-case((text:groups($fn, '\.(\w+)$'))[2])
  return
    replace($unparsed-extension, 'jpg', 'jpeg')
    (: special jpg handling for xdb:store to get correct mime-type :)
};

(: ======================================================================
   Checks extension is compatible with sequence of accepted extensions
   Returns an error string or empty
   TODO: localize error message
   ======================================================================
:)

declare function misc:check-extension( $extension as xs:string, $accept as xs:string* ) as xs:string?
{
  if (empty(fn:index-of($accept, $extension))) then
    concat('File format ', upper-case($extension), ' not supported, please upload only ',
      string-join($accept, ' or '), ' files')
  else
    ()
};

(: ======================================================================
   Updates or creates an entry for a binary resource file inside a host Resources record
   Clean up previous entry (including binary resource file) from database
   ======================================================================
:)
declare function misc:update-resource ( $col-uri as xs:string, $filename as xs:string, $name as xs:string, $host as element(), $alt as xs:string? ) {
  let $legacy := $host/Resources/*[local-name(.) eq $name]
  let $delete := string($legacy)
  return
    if ($legacy) then (
      update value $legacy with $filename,
      if ($legacy/@Date) then (: defensive :)
        update value $legacy/@Date with string(current-dateTime())
      else
        update insert attribute { 'Date' } { current-dateTime() } into $legacy,
      if (util:binary-doc-available(concat($col-uri, '/', $delete))) then (: cleanup previous binary file :)
        (
        xdb:remove($col-uri, $delete),
        if ($alt) then
          let $more := replace($delete, '\.', concat($alt, '.'))
          return
            if (util:binary-doc-available(concat($col-uri, '/', $more))) then (: clean up alternative file, e.g -thumb image file :)
              xdb:remove($col-uri, $more)
            else
              ()
        else
          ()
        )
      else
        ()
      )
    else
      let $resources := $host/Resources
      let $entry := element { $name } { attribute { 'Date' } { current-dateTime() }, $filename }
      return
        if ($resources) then
          update insert $entry into $resources
        else
          update insert <Resources>{ $entry }</Resources> into $host
};

(: ======================================================================
   Streams binary file or returns a 404
   Returns very long duration Cache-Control header
   The cache-scope should indicate public or private depending if
   the resource can be cached by proxy servers or not
   ======================================================================
:)
declare function misc:get-binary-file( $file-uri as xs:string, $mime as xs:string, $cache-scope as xs:string? ) {
  if (util:binary-doc-available($file-uri)) then
    let $file := util:binary-doc($file-uri)
    return (
      if ($cache-scope) then (
        response:set-header('Pragma', 'x'),
        (: to prevent Pragme: no-cache header :)
        response:set-header('Cache-Control', concat($cache-scope, ', max-age=900000'))
        )
      else
        (),
      response:stream-binary($file, $mime)
    )
  else
    ( "Erreur 404 (no file)", response:set-status-code(404) )
};

(: ======================================================================
   Returns current counter variable value and increment it for next time
   Lazy creation of counter variable set to 1 if it does not exists
   Pre-condition: Variables element in global information collection
   ======================================================================
:)
declare function misc:increment-variable( $name as xs:string, $host as element() ) as xs:string {
  let $var := $host/Variables/Variable[Name = $name]
  let $value := $var/Value
  let $cur := if ($value castable as xs:integer) then xs:integer($value) else ()
  return
    if (not(empty($cur))) then (
      update value $value with ($cur + 1),
      string($cur)
      )
    else (: lazy creation - for minimal installation :)
      let $start := 1
      let $seed := <Variable><Name>{ $name }</Name><Value>{ $start + 1 }</Value></Variable>
      return (
        if (empty($var)) then
          if ($host/Variables)then
            update insert $seed into $host/Variables
          else
            update insert <Variables>{ $seed }</Variables> into $host
        else if ($value) then (: non numerical initial value - should never happen ? :)
          update value $value with ($start + 1)
        else
          update insert $seed/Value into $var,
        string($start)
        )
};

(: ======================================================================
   Creates the $path hierarchy of collections directly below the $base-uri collection.
   The $path is a relative path not starting with '/'
   The $base-uri collection MUST be available.
   Returns the database URI to the terminal collection whatever the outcome.
   ======================================================================
:)
declare function misc:create-collection-lazy ( $base-uri as xs:string, $path as xs:string, $user as xs:string, $group as xs:string, $perms as xs:string ) as xs:string*
{
  let $set := tokenize($path, '/')
  return (
    for $t at $i in $set
    let $parent := concat($base-uri, '/', string-join($set[position() < $i], '/'))
    let $path := concat($base-uri, '/', string-join($set[position() < $i + 1], '/'))
    return
     if (xdb:collection-available($path)) then
       ()
     else
       if (xdb:collection-available($parent)) then
         if (xdb:create-collection($parent, $t)) then
           compat:set-owner-group-permissions($path, $user, $group, $perms)
         else
           ()
       else
         (),
    concat($base-uri, '/', $path)
    )[last()]
};

(: ======================================================================
   TODO: throw error
   ======================================================================
:)
declare function misc:create-entity( $base-url as xs:string, $name as xs:string, $entity as element() ) as empty() {
  let $spec := fn:doc(concat('/db/www/', $globals:app-name, '/config/database.xml'))//Entity[@Name = $name]
  let $policy := fn:doc(concat('/db/www/', $globals:app-name, '/config/database.xml'))//Policy[@Name = $spec/@Policy]
  let $col-uri := misc:create-collection-lazy($base-url, $spec/@Collection, $policy/@Owner, $policy/@Group, $policy/@Perms)
  return
    if ($col-uri) then
      let $res-uri := concat($col-uri, '/', $spec/@Resource)
      return
        if (fn:doc-available($res-uri)) then (: append to resource file :)
           update insert $entity into fn:doc($res-uri)/*[1]
        else (: first time creation :)
        let $data := element { string($spec/@Root) } { $entity }
        let $stored-path := xdb:store($col-uri, string($spec/@Resource), $data)
        return
          if(not($stored-path eq ())) then
            compat:set-owner-group-permissions($stored-path, $policy/@Owner, $policy/@Group, $policy/@Perms)
          else
            ()
    else
      ()
};

(: ======================================================================
   Resolve $proxy_name cache with $insert as parent node using remote
   subdocument declared into $proxy_name/Destination
   ======================================================================
:)
declare function misc:create-proxy( $host as element(), $proxy_name as xs:string) as element()* {
  let $proxy := fn:doc($globals:proxies-uri)//Proxy[@Root eq $proxy_name]
  return
    if ($proxy) then
      let $cached_data := $host/Proxies/*[local-name(.) eq $proxy_name] (: what is cached into the proxy :)
      return
        if ($cached_data) then
          (: bootstrap new subdocument @Parent from what have been cached :)
          element { $proxy/Destination/@Parent } { $cached_data/* } (: no side effect : caller is responsible for inserting new element :)
        else
          ()
    else (: TODO : log error ? :)
      ()
};

(: ======================================================================
   Load data from a cache located in $host
   ======================================================================
:)
declare function misc:read-proxy-cache($host as element(), $proxy_name as xs:string) as element()* {
  $host/Proxies/*[local-name(.) eq $proxy_name] (: what is cached into the proxy :)
};

(: ======================================================================
   Load data directly from the document located in $doc
   ======================================================================
:)
declare function misc:read-proxy-doc($doc as element(), $proxy_name as xs:string) as element()* {
  let $proxy := fn:doc($globals:proxies-uri)//Proxy[@Root eq $proxy_name]
  return
    if ($proxy) then
      element { $proxy_name }
      {
        for $field in $proxy/Destination/DataField
        return $doc/*[local-name(.) eq $proxy/Destination/@Parent]/*[local-name(.) eq $field] (: what is stored into the document :)
      }
    else (: TODO : log error ? :)
    ()
};

(: =======================================================================
   Save $data in remote document with node $parent
   AXIOM : $data parent node explicitly defines the proxy used
   =======================================================================
:)
declare function misc:save-proxy($host as element(), $data as element()?) {
  let $proxy_name := local-name($data)
  let $proxy := fn:doc($globals:proxies-uri)//Proxy[@Root eq $proxy_name]
  let $doc_name := $proxy/Destination/@Parent
  return
    if ($data) then
      let $doc := $host/*[local-name() eq $doc_name]
      return
        if ($doc) then
          for $field in $data/*
          let $legacy := $doc/*[local-name(.) eq local-name($field)]
          return
            if ($legacy) then
              update replace $legacy with $field
            else
              update insert $field into $doc
        else
          update insert element { $doc_name }
          {
            for $field in $proxy/Destination/DataField
            return $data/*[local-name(.) eq $field]
          }
          into $host
    else ()
};

(: =======================================================================
   Update cached proxy data in $host
   =======================================================================
:)
declare function misc:record-proxy($host as element(), $data as element()?) {
  if ($host/Proxies) then
    misc:save-content($host/Proxies, $host/Proxies/*[local-name(.) eq local-name($data)], $data)
  else
    update insert <Proxies> { $data } </Proxies> into $host
};

