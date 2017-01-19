xquery version "1.0";
(: --------------------------------------
   CCTRACKER -Oppidoc Case Tracker

   Creation: Christine Vanoirbeek & Stéphane Sire

   CRUD controller to manage notifications messages (alert and email)

   E-mail templates are stored in global-information/email.xml :
   - Alert element : do not define an explicit To field but use an Addressees 
     drop down list (see formulars/alert.xml) to select multiple recipients
     (always used for messages triggered by workflow status changed)
   - Email element : define an explicit (free text) To field to edit a single
     pre-generated recipient and a fixed (non editable) CC field used in some cases
     (see formulars/email.xml) and an attachment field also used in some cases

   December 2014 - (c) Copyright 2014 Oppidoc SARL. All Rights Reserved.
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace media = "http://oppidoc.com/ns/cctracker/media" at "../../lib/media.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "workflow.xqm";
import module namespace check = "http://oppidoc.com/ns/cctracker/check" at "../../lib/check.xqm";
import module namespace email = "http://oppidoc.com/ns/cctracker/mail" at "../../lib/mail.xqm";
import module namespace alert = "http://oppidoc.com/ns/cctracker/alert" at "alert.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Generates content to prefill an Alert message to be displayed using 
   notification.xml formular 
   The Sender field is not editable, thus it can contain a person's name
   or a generic sender mailbox
   ======================================================================
:)
declare function local:prefill-message( $context as xs:string, $workflow as xs:string, $case as element(), $activity as element()? ) as element() {
  let $spec := fn:doc($globals:application-uri)/Application/Messages/Email[@Context eq $context]
  let $recipients := $spec/Recipients
  let $send-to := workflow:gen-recipient-refs($recipients/text(), $workflow, $case, $activity)
  (: cc: automatically added when posting :)
  let $alert := email:render-alert(if ($spec/@Template) then $spec/@Template else 'Unkown', 'en', $case, $activity)
  return (: by default Date and Sender prefilled directly from form.xql :)
    <Alert>
      { misc:rename-element('Sender', $alert/From) }
      <Addressees>
        {
        for $a in $send-to
        return  <AddresseeRef>{ $a }</AddresseeRef>
        }
      </Addressees>
      { $alert/( Subject | Message) }
    </Alert>
};

(: ======================================================================
   Generates content to prefill a status change notification Alert message 
   to be displayed using notification.xml formular 
   This MUST be called after the transition has been saved into the database
   See also alert:notify-transition in alert.xqm
   ======================================================================
:)
declare function local:prefill-notification( $workflow as xs:string, $case as element(), $activity as element()? ) as element() {
  let $item := if ($activity) then $activity else $case
  let $wf-to := $item/StatusHistory/CurrentStatusRef/text()
  let $wf-from := $item/StatusHistory/PreviousStatusRef/text()
  let $transition := if ($wf-from) then workflow:get-transition-for($workflow, $wf-from, $wf-to) else ()
  let $check-login := $transition/@Template eq 'kam-notification'
  let $template :=
    if ($transition/@Template) then
      if ($check-login) then
        concat(string($transition/@Template), alert:check-user-has-login($case/Management/AccountManagerRef))
      else
        string($transition/@Template)
    else
      concat(lower-case($workflow), '-workflow-alert')
  let $extra-vars := alert:gen-action-status-names($wf-from, $wf-to, $workflow) (: not in variables.xml :)
  let $alert := email:render-alert($template, 'en', $case, $activity, $extra-vars)
  return (: by default Date and Sender prefilled directly from form.xql :)
    <Alert>
      { 
      misc:rename-element('Sender', $alert/From),
      workflow:gen-recipients($wf-from, $wf-to, $workflow, $case, $activity),
      $alert/(Subject | Message) 
      }
    </Alert>
};

(: ======================================================================
   Saves a time stamp (Date, SentByRef) instead of existing one in parent
   or create it the first time
   ======================================================================
:)
declare function local:save-timestamp( $parent as element(), $legacy as element()?, $tag as xs:string ) {
  let $stamp :=
    element { $tag } {
      (
      <Date>{ current-dateTime() }</Date>,
      misc:gen-current-person-id('SentByRef'),
      if ($legacy) then (: persists any extra field :)
        $legacy/*[not(local-name(.) = ('Date', 'SentByRef'))]
      else
        ()
      )
    }
  return
    if ($legacy) then
      update replace $legacy with $stamp
    else
      update insert $stamp into $parent
};

(: ======================================================================
   Generates E-mail message content to pre-fill a message for SME Agreement
   TODO: simplify with email:render-alert
   ======================================================================
:)
declare function local:prefill-sme-agreement-email( $case as element(), $activity as element() ) {
  let $contact := $case/NeedsAnalysis/ContactPerson
  let $coach-email := misc:gen-person-email($activity/Assignment/ResponsibleCoachRef)
  let $vars :=
    <vars>
      <var name="Mail_From">{ $coach-email }</var>
      <var name="Mail_To">{ $contact/Contacts/Email/text() }</var>
      <var name="Project_Acronym">{ $case/Information/Acronym/text() }</var>
      <var name="Project_Title">{ $case/Information/Title/text() }</var>
      <var name="First_Name">{ $case/Information/ContactPerson/Name/FirstName/text() }</var>
      <var name="Last_Name">{ $case/Information/ContactPerson/Name/LastName/text() }</var>
      { alert:gen-user-name-for('KAM', $case/Management/AccountManagerRef) }
      { alert:gen-user-name-for('Coach', $activity/Assignment/ResponsibleCoachRef) }
      <var name="Needs_Analysis_Date">{ $case/NeedsAnalysis/Analysis/Date/text() }</var>
    </vars>
  let $mail := media:render-email('sme-agreement', $vars, 'en')
  return
    <Email>
      { $mail/* }
      <Attachment>
        <pre>{ media:message-to-plain-text(local:gen-coaching-plan-for($case, $activity)) }</pre>
      </Attachment>
    </Email>
};

(: ======================================================================
   Generates a neutral CoachingPlan model suitable for :
   - archiving inside storage into activity messages document
   - conversion to plain text for concatenating to email message
     and on-screen display inside Email modal window editor
   - conversion to HTML for on-screen display (see alert-modal.xsl)
   NOTE: could be used to generate an attachement in richer formats (HTML, PDF ?)
   TODO: List with ListHeader (if needed)
   ======================================================================
:)
declare function local:gen-coaching-plan-for( $case as element(), $activity as element() ) as element() {
  let $project-title := $case/Information/Title/text()
  let $contact := $case/NeedsAnalysis/ContactPerson
  let $na-contact := concat(if ($contact/Sex eq 'M') then "M." else "Ms.", " ", $contact/Name/LastName, "  ", $contact/Name/FirstName)
  let $na-date := $case/NeedsAnalysis/DateOfNeedsAnalysis/text()
  let $coach := display:gen-person-name($activity/Assignment/ResponsibleCoachRef/text(), 'en')
  let $kam := display:gen-person-name($case/Management/AccountManagerRef/text(), 'en')
  let $crlf := codepoints-to-string((13))
  return
    <CoachingPlan>
      <Title>Coaching plan proposal</Title>
      <Text>Objectives</Text>
      <List>
        {
          for $obj in $activity/FundingRequest/Objectives/Text
          return
            <Item>{ $obj/text() }</Item>
        }
      </List>
      <Text>Tasks</Text>
      <List>
        {
          for $task at $i in $activity/FundingRequest/Budget/Tasks/Task
          return
            <Item>{ concat(replace($task/NbOfHours, '[^\d]', ''), "H: ", normalize-space($task/Description)) }</Item>
        }
      </List>
      <Text>Total number of hours : { $activity/FundingRequest/Budget/Tasks/TotalNbOfHours/text() }H</Text>
    </CoachingPlan>
};

(: ======================================================================
   Submits coaching plan as attachment to SME for agreement
   TODO: also archive $cc
   ======================================================================
:)
declare function local:send-agreement-email( $case as element(), $activity as element(), $submitted as element() ) as element()? {
  let $attachment := <Attachment>{ local:gen-coaching-plan-for($case, $activity)/* }</Attachment>
  let $cc := misc:gen-person-email($activity/Assignment/ResponsibleCoachRef)
  let $res := local:add-email('Activity', $activity, $submitted, $cc, 'en', $attachment)
  return
    if (local-name($res) eq 'success') then
      (
      local:save-timestamp($activity/FundingRequest, $activity/FundingRequest/SME-Agreement, 'SME-Agreement'),
      $res
      )
    else
      $res
};

(: ======================================================================
   Validates Alert or Email submitted data.
   Returns an empty sequence or a list of thrown errors
   TODO:
   - check local-name($submitted) = ('Alert', 'Email')
   - check From / To with regexp (in addition to formular's check)
   ======================================================================
:)
declare function local:validate-submission( $submitted as element() ) as element()* {
  let $name := local-name($submitted)
  return (
    if ($name eq 'Alert') then
      if (empty($submitted//AddresseeRef)) then
        ajax:throw-error('NO-RECIPIENT', ())
      else
        ()
    else if ($name eq 'Email') then
      if (empty($submitted/To[. ne ''])) then
        ajax:throw-error('NO-RECIPIENT', ())
      else
        ()
    else
      ajax:throw-error('VALIDATION-ROOT-ERROR', $name)
    )
};

(: ======================================================================
   Handles Ajax protocol to report success with Location header to redirect to workflow page
   or with inline message model to include it into messages table
   ======================================================================
:)
declare function local:report-success( $workflow as xs:string, $lang as xs:string, $alert as element(), $base as xs:string ) {
  if (request:get-parameter('next', ()) = 'redirect') then
    let $cmd := oppidum:get-command()
    return
      if ($workflow eq 'Case') then
        ajax:report-success-redirect('ACTION-ALERT-CREATED', (),
          concat($cmd/@base-url, string-join(tokenize($cmd/@trail,'/')[position() <= 2],'/')))
      else
        ajax:report-success-redirect('ACTION-ALERT-CREATED', (),
          concat($cmd/@base-url, string-join(tokenize($cmd/@trail,'/')[position() <= 4],'/')))
  else
    let $payload := workflow:gen-alert-for-viewing($workflow, $lang, $alert, $base)
    return
        ajax:report-success('ACTION-ALERT-CREATED', (), $payload)
};

(: ======================================================================
   Returns e-mail address of the Sender from submitted data or generate 
   current user's e-mail address as default one
   Note that eventually to avoid client-side forgery we could also 
   reconstitute a static from address using the original e-mail template
   ====================================================================== 
:)
declare function local:gen-reply-to-for-alert( $submitted as element() ) as xs:string? {
  if (check:is-email($submitted/Sender/text())) then
    $submitted/Sender/text()
  else
    media:gen-current-user-email(false())
};

(: ======================================================================
   Returns an Alert element for achiving an e-mail
   Merges to (list of AddresseeRef) and cc for archival
   TODO: eventually support @Key on Recipients (but how because of client-side indirection ?)
   ====================================================================== 
:)
declare function local:gen-alert-for-writing( $from as xs:string?, $send-cc as xs:string*, $submitted as element() ) as element()
{
    <Alert>
      <Addressees>
        {
        $submitted/Addressees/AddresseeRef,
        for $a in $send-cc
        return  <AddresseeRef CC="1">{ $a }</AddresseeRef>
        }
      </Addressees>
      {
      if ($from) then <From>{ $from }</From> else (),
      $submitted/(To | Subject | Message)
    }
    </Alert>
};

(: ======================================================================
   Sends and saves a submitted Alert
   See also formulars/notification.xml
   Returns Ajax success or error
   TODO: include an explicit CC field in formulars/notification.xml
   to read the CC from submitted data (this may imply to de-duplicate
   $send-to and $send-cc ?); that would allow to merge add-notification and add-message
   ======================================================================
:)
declare function local:add-alert(
  $workflow as xs:string,
  $host as element(),
  $submitted as element(),
  $send-cc as xs:string*,
  $lang as xs:string ) as element()?
{
  let $errors := local:validate-submission($submitted)
  return
    if (empty($errors)) then
      let $from := local:gen-reply-to-for-alert($submitted)
      let $send-to := $submitted/Addressees/AddresseeRef[. != '-1']/text()
      let $total := count($send-to)
      let $res := alert:send-email-to('workflow', $from, $send-to, $send-cc, $submitted)
      return
        if (($total eq 0) or (count($res[local-name(.) eq 'error']) < $total)) then 
          (: TODO: add error in case count($mailErrors) > 0 
             succeeded for at list one recipient => archives it :)
          let $archive := local:gen-alert-for-writing($from, $send-cc, $submitted)
          return
            local:save-message($workflow, $host, $archive, (), $lang)
        else
          (: TODO : archive it anyway with a flag to tell it could not be sent ? :)
          oppidum:throw-error('SEND-MULTI-EMAIL-FAILURE', string-join($res, ','))
    else
      ajax:report-validation-errors($errors)
};

(: ======================================================================
   Sends and saves a status change Alert or a spontaneous Alert 
   FIXME: @CC not supported on Recipient 
   (would require to include it into client-side formular)
   ======================================================================
:)
declare function local:add-notification( $workflow as xs:string, $host as element(), $submitted as element(), $lang as xs:string ) as element()*
{
  local:add-alert( $workflow, $host, $submitted, (),  $lang)
};

(: ======================================================================
   Sends an saves a document based Alert (tiggered on document save)
   These alerts are declared in Messages part of config/application.xml
   and must be triggered by responding a forward element in a CRUD controller
   ======================================================================
:)
declare function local:add-message( $context as xs:string, $workflow as xs:string, $case as element(), $activity as element()?, $submitted as element(), $lang as xs:string ) as element()*
{
  let $host := if ($activity) then $activity else $case
  let $spec := fn:doc($globals:application-uri)/Application/Messages/Email[@Context eq $context]
  let $send-cc := workflow:gen-recipient-refs($spec/Recipients/@CC, $workflow, $case, $activity)
  return
    local:add-alert($workflow, $host, $submitted, $send-cc, $lang)
};

(: ======================================================================
   Sends and saves an Email message 
   See also formulars/email.xml
   Currently used for coaching plan submission to SME
   TODO: convert attachment to HTML ?
   ======================================================================
:)
declare function local:add-email(
  $workflow as xs:string,
  $parent as element(),
  $submitted as element(),
  $cc as xs:string?,
  $lang as xs:string,
  $attachment as element()?
  ) as element()*
{
  let $errors := local:validate-submission($submitted)
  let $break := codepoints-to-string((13, 10))
  let $long-break := codepoints-to-string((13, 10, 13, 10))
  return
    if (empty($errors)) then
      let $from := normalize-space($submitted/From/text())
      let $to := normalize-space($submitted/To/text())
      let $subject := $submitted/Subject/text()
      let $content := string-join(
        (media:message-to-plain-text($submitted/Message),media:message-to-plain-text($attachment)),
        $long-break)
      return
        if (media:send-email('action', $from, $to, $cc, $subject, $content)) then
          local:save-message($workflow, $parent, $submitted, $attachment, $lang )
        else
          oppidum:throw-error('SEND-EMAIL-FAILURE', $to)
    else
      ajax:report-validation-errors($errors)
};

(: ======================================================================
   Archives a submitted message (Alert or Email) into the Case or Activity
   Returns an Ajax protocol response
   ======================================================================
:)
declare function local:save-message(
  $workflow as xs:string,
  $parent as element(),
  $submitted as element(),
  $attachment as element()?,
  $lang as xs:string
  ) as element()*
{
  let $saved := alert:archive($parent, $submitted, $attachment,
                  $parent/StatusHistory/CurrentStatusRef/text(),
                  $parent/StatusHistory/PreviousStatusRef/text(), $lang)
  return
    if (local-name($saved) eq 'Alert') then
      local:report-success($workflow, $lang, $saved, $parent/No)
    else (: must be an error :)
      $saved
};

(: ======================================================================
   Returns the message with Id $ref
   NB: currently this is to generate modal window content with alert-modal.xsl
   ======================================================================
:)
declare function local:get-message( $workflow as xs:string, $host as element(), $ref as xs:string, $lang as xs:string) as element()* {
  let $item := $host/Alerts/Alert[Id = $ref]
  return
    if ($item) then
      workflow:gen-alert-for-viewing($workflow, $lang, $item, ())
    else
      oppidum:throw-error("URI-NOT-FOUND", ())
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $doc-id := string($cmd/resource/@name)
let $lang := string($cmd/@lang)
let $case-no := tokenize($cmd/@trail, '/')[2]
let $case := fn:collection($globals:cases-uri)/Case[No eq $case-no]
let $tokens := tokenize($cmd/@trail, '/')
let $activity-no := if ($tokens[3] eq 'activities') then $tokens[4] else ()
let $activity := if ($activity-no) then $case/Activities/Activity[No = $activity-no] else ()
let $target := if ($activity-no) then 'Activity' else 'Case'
let $item := if ($activity-no) then $activity else $case
return
  if ($item) then
    if ($m = 'POST') then
      let $submitted := request:get-data()
      return
        if ($doc-id = 'alerts') then
          (: Ignores the goal=init parameter :)
          let $from := request:get-parameter('from', ())
          return
            (: TODO : check access right :)
            if ($from eq 'SME-Agreement') then
              local:send-agreement-email($case, $activity, $submitted)
            else if ($from = 'FundingDecision') then
              local:add-message($from, $target, $case, $activity, $submitted, $lang)
            else
              local:add-notification($target, $item, $submitted, $lang)
        else
          ()
    else (: assumes GET :)
      let $goal := request:get-parameter('goal', 'read')
      let $from := request:get-parameter('from', ())
      return
        if ($goal = 'init') then
          if ($from = 'status') then
            local:prefill-notification($target, $case, $activity)
          else if ($from = 'SME-Agreement') then
            local:prefill-sme-agreement-email($case, $activity)
          else if ($from = 'FundingDecision') then
            local:prefill-message($from, $target, $case, $activity)
          else
            email:render-alert(concat(lower-case($target), '-spontaneous-alert'), 'en', $case, $activity)
        else if ($doc-id = 'alerts') then (: not mapped :)
          <Alerts/>
        else (: assumes 'read' :)
          local:get-message($target, $item, $doc-id, $lang)
  else
    oppidum:throw-error("URI-NOT-FOUND", ())
