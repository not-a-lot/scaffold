xquery version "1.0";
(: --------------------------------------
   Oppidoc Business Application Development Framework

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Media services, currently e-mail

   Note that if you use "!localhost" as SMTP server address, email messages
   will not be sent, but instead, if you have created a '/db/debug/debug.xml'
   file inside your database with a <Debug> root element
   (do not forget to configure it with write access for everyone)
   then email messages will be copied into it.

   November 2016 - (c) Copyright 2016 Oppidoc SARL. All Rights Reserved.
   ----------------------------------------------- :)

module namespace media = "http://oppidoc.com/ns/cctracker/media";

import module namespace mail = "http://exist-db.org/xquery/mail";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace user = "http://oppidoc.com/ns/user" at "user.xqm";

(: ======================================================================
   Utility to return current user E-mail address or the empty sequence
   or a message if explain is true
   ======================================================================
:)
declare function media:gen-current-user-email( $explain as xs:boolean ) as xs:string? {
  let $uid := user:get-current-person-id()
  let $user := fn:doc($globals:persons-uri)/Persons/Person[Id = $uid]
  let $res := $user/Contacts/Email/text()
  return
    if ($res) then (: TODO: check syntax ? :)
      normalize-space($res)
    else if ($explain) then (: TODO: localize :)
      "please enter your email address in your profile"
    else (: no explanation, send-email will use default sender :)
      ()
};

(: ======================================================================
   Generates an Email model from the name template and the variables
   ======================================================================
:)
declare function media:render-email( $name as xs:string, $vars as element()?, $lang as xs:string ) as element() {
  let $template := fn:collection($globals:global-info-uri)//Email[@Name eq $name][@Lang eq $lang]
  return
    if ($template) then
      local:render-email-iter($template, $vars)
    else
      <Email>
        <Message>
          <Text>Template "{ $name }" not found, please contact a database administrator !</Text>
        </Message>
      </Email>
};

(: ======================================================================
   Generates an Alert model from the name template and the variables
   ======================================================================
:)
declare function media:render-alert( $name as xs:string, $vars as element()?, $lang as xs:string ) as element() {
  let $template := fn:collection($globals:global-info-uri)//Alert[@Name eq $name][@Lang eq $lang]
  return
    if ($template) then
      local:render-email-iter($template, $vars)
    else
      <Alert>
        <Message>
          <Text>Template "{ $name }" not found, please contact a database administrator !</Text>
        </Message>
      </Alert>
};
(: ======================================================================
   Renders (an email) template injecting @@vars@@ in text content
   FIXME:
   - temporary hack turn Block / Line into Text (need to implement 'input' plugin multilines='enhanced')
   ======================================================================
:)
declare function local:render-email-iter( $nodes as item()*, $vars as element()? ) as item()* {
  for $node in $nodes
  return
    typeswitch($node)
      case text()
        return local:replace-variables($node, $vars, 1)
      case attribute() return
        attribute { node-name($node) }
          { $node/string() }
      case element() return
        if ($node/@Repeat eq '*' ) then (: assumes a terminal Text or Line node :)
          let $driver := tokenize($node/text(), '@@')[2]
          let $total := count($vars/var[@name eq $driver])
          for $i in (1 to max(($total, 1)))
          return
            element { node-name($node) }
              { local:replace-variables($node/text(), $vars, $i) }
        else
          element { node-name($node) }
            { local:render-email-iter($node/(attribute()|node()), $vars) }
      default return $node
};

(: ======================================================================
   Substitutes @@vars@@ inside a single string of text
   ======================================================================
:)
declare function local:replace-variables( $text as xs:string, $vars as element()?, $rank as xs:integer ) as xs:string {
  if (not(contains($text, "@@"))) then
    $text
  else
    string-join(
      for $t at $i in tokenize($text, '@@')
      return
        if ($i mod 2 eq 0) then
          $vars/var[@name eq $t][$rank]/text()
        else
          $t,
      ''
      )
};

(: ======================================================================
   Replaces elements in message with Visibility="obfuscate" with obfuscated content
   This is a type switch expression that filter the message model
   ======================================================================
:)
declare function media:obfuscate( $nodes as item()* ) as item()* {
  for $node in $nodes
  return
    typeswitch($node)
      case text()
        return $node
      case attribute()
        return $node
      case element()
        return
          if ($node/@Visibility eq 'obfuscate') then
            element { node-name($node) } { '*** content voluntarily hidden ***' }
          else
            element { node-name($node) }
              { media:obfuscate($node/(attribute()|node())) }
      default
        return $node
};

(: ======================================================================
   Converts a simple Text / Block document model into plain text
   (e.g. to send by e-mail)
   ======================================================================
:)
declare function media:message-to-plain-text( $message as element()? ) {
  let $break := codepoints-to-string((13, 10))
  let $long-break := codepoints-to-string((13, 10, 13, 10))
  return
    string-join(
      for $line in $message/*
      return
        if (local-name($line) eq 'Text') then
          $line/text()
        else if (local-name($line) eq 'Block') then
          string-join(
            for $item in $line/Line return $item/text(),
            $break)
        else if (local-name($line) eq 'Title') then
          let $hr := string-join(for $i in 1 to string-length($line/text()) return '=', '')
          return concat($line/text(), $break, $hr)
        else if (local-name($line) eq 'List') then
          let $sep := if (some $line in $line/Item satisfies (string-length($line) > 79)) then
                        $long-break
                      else
                        $break
          return
            string-join(
              for $item in $line/Item return normalize-space($item/text()),
              $sep)
        else
          ()
      , $long-break)
};

(: ======================================================================
   Intercepts Exception while contacting the email server
   Returns false() to allow error feedback
   Eventually let clause should do some logging into a file or into the database to record the error
   ======================================================================
:)
declare function local:report-exception( $to as xs:string ) as xs:boolean
{
 let $err :=  concat("Failed to send email message : ", $util:exception-message)
 return
   false()
};

(: ======================================================================
   Returns true if the given category is plugged which implies e-mail
   will really be sent
   ======================================================================
:)
declare function media:is-plugged( $category as xs:string ) as xs:boolean {
  let $server := fn:doc($globals:settings-uri)/Settings/SMTPServer/text()
  let $allow := fn:doc($globals:settings-uri)/Settings/Media/Allow/Category/text()
  return
    not(starts-with($server, '!')) and ($category = $allow)
};

(: ======================================================================
   Sends an e-mail message to a single recipient using the SMTP server
   defined in the application settings (SMTP server w/o authentification)
   The category is used to selectively branch debug on or off
   NOTE: normalize-space is okay as long as we do not allow spaces inside email addresses
   ======================================================================
:)
declare function media:send-email(
  $category as xs:string,
  $from as xs:string?,
  $to as xs:string,
  $subject as xs:string?,
  $content as xs:string?
  ) as xs:boolean
{
  media:send-email($category, $from, $to, (), $subject, $content)
};

(: ======================================================================
   Sends an e-mail, full version with an optional list of CC recipients
   ======================================================================
:)
declare function media:send-email(
  $category as xs:string,
  $from as xs:string?,
  $to as xs:string,
  $cc as xs:string*,
  $subject as xs:string?,
  $content as xs:string?
  ) as xs:boolean
{
  let $sender := normalize-space(string(fn:doc($globals:settings-uri)/Settings/DefaultEmailSender))
  let $reply-to := if ($from) then normalize-space($from) else $sender
  let $mail := <mail>
                 <from>{ $sender }</from>
                 <to>{ normalize-space($to) }</to>
                 <reply-to>{ $reply-to }</reply-to>
                 {
                 for $c in $cc[. ne '']
                 return <cc>{ normalize-space($c) }</cc>
                 }
                 <subject>{ if ($subject) then $subject else 'no subject' }</subject>
                 <message><text>{ if ($content) then $content else 'no content' }</text></message>
               </mail>
  let $plug := media:is-plugged($category)
  let $debug := fn:doc($globals:settings-uri)/Settings/Media/Debug/Category/text()
  let $server := fn:doc($globals:settings-uri)/Settings/SMTPServer/text()
  return (
    let $sent :=
      if ($plug) then
        if (util:catch('*', mail:send-email($mail, $server, ()), local:report-exception($to))) then
          true()
        else if (fn:doc-available('/db/debug/debug.xml')) then (: logs to debug in case of failure  :)
          let $archive := <mail status="error" date="{ current-dateTime() }">{ $mail/* }</mail>
          return (
            util:catch('*', update insert $archive into fn:doc('/db/debug/debug.xml')/Debug, local:report-exception('debug')),
            false()
            )[last()]
        else
          false()
      else (: fakes success :)
        true()
    return
      if ($sent) then (: optional log into debug :)
        if (($category = $debug) and (fn:doc-available('/db/debug/debug.xml'))) then
          let $archive :=
            <mail date="{ current-dateTime() }">
              {(
              if (not($plug)) then attribute { 'status' } { 'unplugged' } else (),
              $mail/*
              )}
            </mail>
          return (
            util:catch('*', update insert $archive into fn:doc('/db/debug/debug.xml')/Debug, local:report-exception('debug')),
            true()
            )[last()]
        else
          true()
      else (: was already logged into debug :)
        true()
    )[last()]
};
