<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site" xmlns:xt="http://ns.inria.org/xtiger"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="application/xhtml+xml" omit-xml-declaration="yes" indent="yes"/>

  <xsl:include href="../../modules/activities/activity.xsl"/>
  <xsl:include href="../../lib/commons.xsl"/>
  <xsl:include href="../../lib/widgets.xsl"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <!-- Disjonctive entry point calling Display when rendering full page or success to return an Ajax response -->
  <xsl:template match="/">
    <xsl:apply-templates select="Display | success | error"/>
  </xsl:template>

  <!-- Ajax protocol for alert posting or annex uploading :
       - errors raised via oppidum:throw-error that set a status code cut the pipeline and wont go through here
       - preflight part of annex upload protocol does not have payload  -->
  <xsl:template match="success">
    <success>
      <xsl:copy-of select="message"/>
      <xsl:apply-templates select="payload"/>
      <xsl:copy-of select="forward"/>
    </success>
  </xsl:template>

  <!-- Ajax response with payload go through XSLT transformation to generate HTML fragments  -->
  <xsl:template match="payload">
    <payload>
      <xsl:apply-templates select="*"/>
    </payload>
  </xsl:template>

  <!-- Should not happen since errors should raise an HTTP error and cut the pipeline  -->
  <xsl:template match="error">
    <site:view skin="workflow">
      <site:win-title>
        <title>Case Tracker Error</title>
      </site:win-title>
      <site:content>
        <h2>Oops !</h2>
      </site:content>
    </site:view>
  </xsl:template>

  <xsl:template match="Display[@Mode = 'workflow']">
    <site:view skin="workflow">
      <xsl:apply-templates select="Cartouche/Window"/>
      <site:title>
        <h1><xsl:apply-templates select="Cartouche/Title"/></h1>
      </site:title>
      <site:timeline>
        <xsl:apply-templates select="Workflow"/>
      </site:timeline>
      <site:content>
        <div class="row" data-axel-base="{$xslt.base-url}">
          <div class="span12">
            <xsl:apply-templates select="Tabs"/>
            <xsl:apply-templates select="Modals"/>
            <!-- <xsl:apply-templates select="//Activities/Add" mode="activity-modal"/> -->
          </div>
        </div>
        <xsl:apply-templates select="Tabs//AutoExec"/>
      </site:content>
    </site:view>
  </xsl:template>

  <!--****************************-->
  <!--***** Activity Summary *****-->
  <!--****************************-->

  <xsl:template match="Title[parent::Cartouche]"><xsl:value-of select="."/><xsl:apply-templates select="@Source" mode="title"/>
  </xsl:template>

  <xsl:template match="Title[@LinkToCase][parent::Cartouche]">
    <a href="../../{@LinkToCase}"><xsl:value-of select="."/></a><xsl:apply-templates select="@Source" mode="title"/>
  </xsl:template>
  
  <!-- view XML source in 'dev' mode -->
  <xsl:template match="@Source" mode="title"><xsl:text> </xsl:text><sup><a href="{.}">xml</a></sup>
  </xsl:template>

  <!--*******************************-->
  <!--*****  Workflow Timeline  *****-->
  <!--*******************************-->

  <xsl:template match="Workflow">
    <xsl:variable name="offset"><xsl:if test="@Offset"> offset<xsl:value-of select="@Offset"/></xsl:if></xsl:variable>
    <div class="span{@W}{$offset}">
      <ul id="c-workflow" class="{@Name}">
        <xsl:apply-templates select="Step[@Display='step']"/>
      </ul>
    </div>
    <xsl:if test="count(Step[@Display='state']) > 0">
      <div class="span2" style="margin-left:0">
        <xsl:choose>
          <xsl:when test="count(Step[@Display='state'])>0">
            <ul id="c-states">
              <xsl:apply-templates select="Step[@Display='state']"/>
            </ul>
          </xsl:when>
        </xsl:choose>
      </div>
    </xsl:if>
  </xsl:template>

  <xsl:template match="Step[@Display='step']">
    <xsl:variable name="num" select="@Num"/>
    <li>
      <span>
        <xsl:attribute name="class">
          <xsl:if test="position() = 1">c-start </xsl:if>
          <xsl:if test="position() = last()"> c-end </xsl:if>
          <xsl:if test="@Status">
            <xsl:value-of select="concat('c-',@Status)"/>
          </xsl:if>
        </xsl:attribute>
        <xsl:value-of select="/Display/Dictionary/WorkflowStatus/Option[Id/text() = $num]/Name"/>
      </span>
      <xsl:apply-templates select="@StartDate"/>
    </li>
  </xsl:template>

  <xsl:template match="@StartDate">
    <p>
      <xsl:value-of select="string(.)"/>
    </p>
  </xsl:template>

  <xsl:template match="Step[@Display='state']">
    <xsl:variable name="num" select="@Num"/>
    <li>
      <span>
        <xsl:apply-templates select="." mode="class"/>
        <xsl:value-of select="/Display/Dictionary/WorkflowStatus/Option[Id = $num]/Name"/>
      </span>
      <span class="c-timestamp"><xsl:value-of select="string(@StartDate)"/></span>
    </li>
  </xsl:template>

  <xsl:template match="Step[@Display='state'][@StartDate ='']">
    <xsl:variable name="num" select="@Num"/>
    <li>
      <span class="c-decision">
        <xsl:value-of select="/Display/Dictionary/WorkflowStatus/Option[Id = $num]/Name"/>
      </span>
    </li>
  </xsl:template>

  <xsl:template match="Step" mode="class">
    <xsl:attribute name="class">c-decision</xsl:attribute>
  </xsl:template>

  <xsl:template match="Step[@Status = 'current']" mode="class">
    <xsl:attribute name="class">c-decision c-current</xsl:attribute>
  </xsl:template>

  <!-- Simple tab content heading limited to a title -->
  <xsl:template match="Heading">
    <div class="c-tab-heading {@class}">
      <h3 loc="{Title/@loc}">
        <xsl:value-of select="Title"/>
      </h3>
    </div>
  </xsl:template>

  <!--*******************-->
  <!--***** Drawers *****-->
  <!--*******************-->

  <xsl:template match="Drawer[@Command = 'annex']">
    <xsl:variable name="Id">
      <xsl:value-of select="ancestor::Tab/@Id"/>
    </xsl:variable>
    <div class="accordion">
      <div class="accordion-group c-drawer" data-command="drawer" data-target="c-editor-{$Id}"
        data-collapse="#collapse-{ancestor::Tab/@Id}">
        <div class="accordion-heading {@class}">
          <span class="c-document-menu c-perm-menu">
            <button class="btn btn-primary" data-command="annex"
              data-src="{/Display/@ResourceNo}/appendices" data-with-template="{/Display/@ResourceNo}/appendices/template"
              data-target="c-editor-{$Id}" data-append-target="c-annex-list"
              loc="action.add.annex">Ajouter une annexe</button>
          </span>
          <h3 class="c-drawer-title" loc="{Title/@loc}">
            <xsl:value-of select="Title"/>
          </h3>
        </div>
        <div id="collapse-{$Id}" class="accordion-body collapse">
          <div class="accordion-inner">
            <div id="c-editor-{$Id}" data-command="transform">
              <noscript loc="app.message.js">Activez Javascript</noscript>
              <p loc="app.message.loading">Chargement du masque en cours</p>
            </div>
            <div id="c-editor-{$Id}-menu" class="c-editor-menu c-perm-menu">
              <button class="btn btn-primary"
                data-command="trigger" data-trigger-event="axel-cancel-edit"
                data-target="c-editor-{$Id}"
                loc="action.terminate">Terminer</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="Drawer">
    <xsl:variable name="Id">
      <xsl:value-of select="ancestor::Tab/@Id"/>
    </xsl:variable>
    <div class="accordion">
      <div class="accordion-group c-drawer" data-command="drawer" data-target="c-editor-{$Id}">
        <div class="accordion-heading {@class}">
          <span class="c-document-menu c-perm-menu">
            <button class="btn btn-primary"
              data-command="{@Command}" data-edit-action="create"
              data-with-template="{Template}" data-src="{/Display/@ResourceNo}/{Controller}"
              data-target="c-editor-{$Id}" data-target-ui="c-editor-{$Id}-menu"
              loc="{@loc}">
              <xsl:apply-templates select="Initialize"/> Commande</button>
          </span>
          <h3 class="c-drawer-title" loc="{Title/@loc}">
            <xsl:value-of select="Title"/>
          </h3>
        </div>
        <div id="collapse-{$Id}" class="accordion-body collapse">
          <div class="accordion-inner c-editing-mode">
            <div id="c-editor-{$Id}" class="c-autofill-border c-document-editor"
              data-command="transform" data-validation-output="c-editor-{$Id}-errors"
              data-validation-label="label">
              <noscript loc="app.message.js">Activez Javascript</noscript>
              <p loc="app.message.loading">Chargement du masque en cours</p>
            </div>
            <div id="c-editor-{$Id}-errors" class="alert alert-error af-validation"> </div>
            <div id="c-editor-{$Id}-menu" class="c-editor-menu c-menu-scope">
              <button class="btn btn-primary"
                data-command="save c-inhibit" data-save-flags="silentErrors"
                data-target="c-editor-{$Id}"
                loc="action.save">
                <xsl:choose>
                  <xsl:when test="@AppenderId">
                    <xsl:attribute name="data-replace-type">append</xsl:attribute>
                    <xsl:attribute name="data-replace-target"><xsl:value-of select="@AppenderId"/></xsl:attribute>
                  </xsl:when>
                  <xsl:when test="@PrependerId">
                    <xsl:attribute name="data-replace-type">prepend</xsl:attribute>
                    <xsl:attribute name="data-replace-target"><xsl:value-of select="@PrependerId"
                      /></xsl:attribute>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:attribute name="data-replace-type">event</xsl:attribute>
                  </xsl:otherwise>
                </xsl:choose> Enregistrer</button>
              <button class="btn" data-command="trigger"
                data-target="c-editor-{$Id}" data-trigger-event="axel-cancel-edit"
                loc="action.cancel">Annuler</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="Initialize">
    <xsl:attribute name="data-init"><xsl:value-of select="/Display/@ResourceNo"/>/<xsl:value-of
        select="."/></xsl:attribute>
  </xsl:template>

  <!--*********************-->
  <!--***** Accordion *****-->
  <!--*********************-->

  <xsl:template match="Accordion">
    <div class="accordion">
      <xsl:apply-templates select="Document | Drawer"/>
    </div>
  </xsl:template>

  <!-- Display documents into workflow using their XTiger XML template -->
  <xsl:template match="Document">
    <div class="accordion-group c-documents" data-command="view" data-target="c-editor-{@Id}"
      data-target-ui="c-editor-{@Id}-menu" data-with-template="{Template}"
      data-src="{/Display/@ResourceNo}/{Resource}">
      <div class="accordion-heading c-{@Status} {@class}">
        <span class="c-document-menu c-menu-scope"><xsl:apply-templates select="Actions/*[local-name(.) != 'Spawn']"/></span>
        <span id="c-editor-{@Id}-menu" class="c-editor-menu c-menu-scope">
          <xsl:apply-templates select="Actions/Edit" mode="menubar"/>
        </span>
        <h3 class="c-document-title">
          <a class="c-accordion-toggle" data-toggle="collapse" href="#collapse-{@Id}">
            <xsl:copy-of select="Name/@loc"/>
            <xsl:value-of select="Name"/>
          </a>
        </h3>
      </div>
      <div id="collapse-{@Id}" class="accordion-body collapse">
        <div class="accordion-inner">
          <div id="c-editor-{@Id}-errors" class="alert alert-error af-validation"></div>
          <div id="c-editor-{@Id}" class="c-autofill-border" data-command="transform"
            data-validation-output="c-editor-{@Id}-errors" data-validation-label="label">
            <noscript loc="app.message.js">Activez Javascript</noscript>
            <p loc="app.message.loading">Chargement du masque en cours</p>
          </div>
          <!-- duplicated bottom editor menu (conventional -bottom suffix) -->
          <div id="c-editor-{@Id}-menu-bottom" class="c-menu-scope c-editor-menu">
            <xsl:apply-templates select="Actions/Edit" mode="menubar"/>
          </div>
        </div>
      </div>
    </div>
  </xsl:template>

  <!-- Generates editing menu 
       FIXME: currently @Forward assumes Resources ends-up with a ?something parameter (goal)
       -->
  <xsl:template match="Edit" mode="menubar">
    <xsl:if test="@Forward= 'submit'">
      <button class="btn btn-primary" data-command="save c-inhibit" data-save-flags="silentErrors"
        data-target="c-editor-{ancestor::Document/@Id}" data-replace-type="event" loc="action.submit"
        data-src="{/Display/@ResourceNo}/{substring-before(ancestor::Document/Resource, '?')}?submit"><xsl:value-of select="@Forward"/></button>
    </xsl:if>
    <button class="btn btn-primary" data-command="save c-inhibit" data-save-flags="silentErrors"
      data-target="c-editor-{ancestor::Document/@Id}" data-replace-type="event"
      loc="action.save">Enregistrer</button>
    <button class="btn" data-command="trigger"
      data-target="c-editor-{ancestor::Document/@Id}" data-trigger-event="axel-cancel-edit"
      loc="action.cancel">Annuler</button>
  </xsl:template> 

  <!-- Document w/o associated editor (direct visualization of inline items, e.g. closed Logbook) -->
  <xsl:template match="Document[not(Template) and not(Resource)]">
    <div class="accordion-group c-documents">
      <div class="accordion-heading c-{@Status}">
        <h3 class="c-document-title">
          <a class="c-accordion-toggle" data-toggle="collapse" href="#collapse-{@Id}">
            <xsl:copy-of select="Name/@loc"/>
            <xsl:value-of select="Name"/>
          </a>
        </h3>
      </div>
      <div id="collapse-{@Id}" class="accordion-body collapse">
        <div class="accordion-inner">
          <xsl:apply-templates select="Content/*"/>
        </div>
      </div>
    </div>
  </xsl:template>

  <!-- Document with Drawer action to manage the creation of a read-only collection of (small) associated documents
       Currently the Document cannot have it's own editable representation (this is left as a future extension)
       NOTE: this is different than a Drawer directly inside a Tab (see above) -->
  <xsl:template match="Document[Actions/Drawer]">
    <div class="accordion-group c-documents">
      <div class="accordion-heading c-{@Status}">
        <span class="c-document-menu c-menu-scope"><xsl:apply-templates select="Actions/*"/></span>
        <h3 class="c-document-title">
          <a class="c-accordion-toggle" data-toggle="collapse" href="#collapse-{@Id}">
            <xsl:copy-of select="Name/@loc"/>
            <xsl:value-of select="Name"/>
          </a>
        </h3>
      </div>
      <div id="collapse-{@Id}" class="accordion-body collapse">
        <div class="accordion-inner">
          <div id="c-drawer-{@Id}" class="collapse c-drawer" data-command="acc-drawer"
            data-target="c-editor-{@Id}" data-drawer-trigger="c-drawer-{@Id}-action">
            <div id="c-editor-{@Id}" class="c-autofill-border" data-command="transform"
              data-validation-output="c-editor-{@Id}-errors" data-validation-label="label">
              <noscript loc="app.message.js">Activez Javascript</noscript>
              <p loc="app.message.loading">Chargement du masque en cours</p>
            </div>
            <div id="c-editor-{@Id}-errors" class="alert alert-error af-validation"> </div>
            <div id="c-editor-{@Id}-menu" class="c-editor-menu c-menu-scope">
              <button class="btn btn-primary" data-command="save c-inhibit" data-save-flags="silentErrors"
                data-target="c-editor-{@Id}"
                loc="action.save">
                <xsl:choose>
                  <xsl:when test="Actions/Drawer/@AppenderId">
                    <xsl:attribute name="data-replace-type">append</xsl:attribute>
                    <xsl:attribute name="data-replace-target"><xsl:value-of
                        select="Actions/Drawer/@AppenderId"/></xsl:attribute>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:attribute name="data-replace-type">event</xsl:attribute>
                  </xsl:otherwise>
                </xsl:choose> Enregistrer</button>
              <button class="btn"
                data-command="trigger" data-trigger-event="axel-cancel-edit"
                data-target="c-editor-{@Id}"
                loc="action.cancel">Annuler</button>
            </div>
          </div>
          <xsl:apply-templates select="Content/*"/>
        </div>
      </div>
    </div>
  </xsl:template>

  <!-- Removes documents with specific access control on 'read' action -->
  <xsl:template match="Document[Actions/Forbidden]">
  </xsl:template>

  <!--*************-->
  <!--** Actions **-->
  <!--*************-->

  <!-- Accordion 'edit' action to edits the given Resource with a given Template -->
  <xsl:template match="Actions/Drawer">
    <xsl:variable name="Id">
      <xsl:value-of select="ancestor::Document/@Id"/>
    </xsl:variable>
    <button id="c-drawer-{$Id}-action" class="btn btn-primary"
      data-command="edit" data-edit-action="create" data-command-ui="disable"
      data-with-template="{Template}" data-src="{/Display/@ResourceNo}/{Controller}"
      data-target="c-editor-{$Id}" data-target-ui="c-editor-{$Id}-menu"
      loc="{@loc}">
      <xsl:apply-templates select="Initialize"/> Commande</button>
  </xsl:template>

  <!-- Accordion 'edit' action to edits the given Resource with a given Template -->
  <xsl:template match="Edit">
    <button class="btn btn-primary"
      data-command="edit" data-edit-action="update" data-command-ui="hide"
      data-with-template="{Template}" data-src="{/Display/@ResourceNo}/{Resource}"
      data-target="c-editor-{../../@Id}" data-target-ui="c-editor-{../../@Id}-menu">
      <xsl:attribute name="loc">
        <xsl:choose>
          <xsl:when test="@loc"><xsl:value-of select="@loc"/></xsl:when>
          <xsl:otherwise>action.edit</xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      Éditer</button>
  </xsl:template>

  <!-- Accordion 'save' action to spawn a coaching activity for a given Case -->
  <xsl:template match="Spawn[parent::Tab]">
    <p style="text-align:center">
      <button class="btn btn-primary" data-command="confirm" data-src="{/Display/@ResourceNo}/{Controller}">
        <!-- <xsl:attribute name="loc">
                <xsl:choose>
                  <xsl:when test="@loc"><xsl:value-of select="@loc"/></xsl:when>
                  <xsl:otherwise>action.spawn</xsl:otherwise>
                </xsl:choose>
              </xsl:attribute> -->
        Create coaching activity</button>
    </p>
  </xsl:template>

  <xsl:template match="Spawn[parent::Actions]">
    <button class="btn btn-primary" data-command="confirm" data-src="{/Display/@ResourceNo}/{Controller}">Create coaching activity</button>
  </xsl:template>

  <!-- Pseudo-AXEL in place template to use 'c-delete' command -->
  <xsl:template match="Delete">
    <button class="btn btn-primary" data-command="c-delete c-inhibit"
      data-template="#" data-controller="{/Display/@ResourceNo}/delete"
      loc="action.delete">Supprimer</button>
  </xsl:template>

  <!--**********************************-->
  <!--*****  Change status action  *****-->
  <!--**********************************-->

  <!-- Generates status change menu  -->
  <xsl:template match="ChangeStatus[@Status]">
    <xsl:variable name="ted">
      <xsl:value-of select="@TargetEditor"/>
    </xsl:variable>
    <div class="btn-group pull-right" style="margin-left:10px">
      <a class="btn btn-success dropdown-toggle" data-toggle="dropdown" href="#" style="outline:none">
          <span loc="action.status.change">Status</span>
          <span class="caret"/>
      </a>
      <ul class="dropdown-menu"
        data-command="status c-inhibit" data-status-from="{@Status}"
        data-status-ctrl="{/Display/@ResourceNo}/status"
        data-with-template="{/Display/Modals/Modal[@Id = $ted]/Template}"
        data-src="{/Display/@ResourceNo}/{/Display/Modals/Modal[@Id = $ted]/Controller}"
        data-target="{@TargetEditor}" data-target-modal="{@TargetEditor}-modal"
        data-confirm-loc="confirm.status.change">
        <xsl:apply-templates select="@Id"/>
        <xsl:apply-templates select="/Display/Modals/Modal[@Id = $ted]/Initialize"/>
        <xsl:apply-templates select="../Spawn" mode="change-status"/>
        <xsl:apply-templates select="Status" mode="change-status"/>
      </ul>
    </div>
  </xsl:template>

  <!-- Generates pseudo-status change menu with only one option to spawn an activity  -->
  <xsl:template match="ChangeStatus[not(@Status)]">
    <div class="btn-group pull-right" style="margin-left:10px">
      <a class="btn btn-success dropdown-toggle" data-toggle="dropdown" href="#" style="outline:none">
          <span loc="action.status.change">Status</span>
          <span class="caret"/>
      </a>
      <ul class="dropdown-menu">
        <xsl:apply-templates select="@Id"/>
        <xsl:apply-templates select="../Spawn" mode="change-status"/>
      </ul>
    </div>
  </xsl:template>

  <!-- TODO: use Dictionary > Transitions to localize @Label  -->
  <xsl:template match="Status" mode="change-status">
    <xsl:variable name="to" select="string(@To)"/>
    <li>
      <a tabindex="-1" href="#" data-action="{@Action}">
        <xsl:apply-templates select="@Argument"/>
        <xsl:apply-templates select="@Id"/>
        <xsl:choose>
          <xsl:when test="@Label"><xsl:value-of select="@Label"/>
          </xsl:when>
          <xsl:when test="number(parent::ChangeStatus/@Status) &lt; number($to)">
            <xsl:apply-templates select="@Intent"/>Advance to “<xsl:value-of select="/Display/Dictionary/WorkflowStatus/Option[Id = $to]/Name"/>”
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="@Intent"/>Return to “<xsl:value-of select="/Display/Dictionary/WorkflowStatus/Option[Id = $to]/Name"/>”
          </xsl:otherwise>
        </xsl:choose>
      </a>
    </li>
  </xsl:template>

  <xsl:template match="@Argument"><xsl:attribute name="data-argument"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="@Intent[. = 'accept']"><xsl:text>Accept and </xsl:text>
  </xsl:template>

  <xsl:template match="@Intent[. = 'refuse']"><xsl:text>Reject and </xsl:text>
  </xsl:template>

  <xsl:template match="Spawn"  mode="change-status">
    <li>
      <a tabindex="-1" href="#" data-command="confirm" data-src="{/Display/@ResourceNo}/{Controller}"><xsl:apply-templates select="@Id"/>Create new coaching activity</a>
    </li>
  </xsl:template>
  
  <!--***********************************************-->
  <!--*****  Modal window for AutoExec command  *****-->
  <!--***********************************************-->
  
  <!-- Modal version (confirmation dialog) -->
  <xsl:template match="AutoExec">
    <!-- Modal -->
    <div id="{@Id}" class="modal hide fade" tabindex="-1" role="dialog" aria-labelledby="label-alert" aria-hidden="true"
         data-command="autoexec" data-exec="{Forward/@Command}" data-exec-target="{Forward/text()}"
         style="width:700px;margin-left:-350px"
         >
      <xsl:if test="Forward/@EventTarget">
        <xsl:attribute name="data-exec-event-target"><xsl:value-of select="Forward/@EventTarget"/></xsl:attribute>
      </xsl:if>
      <div class="modal-header">
        <h3>Title</h3>
      </div>
      <div class="modal-footer">
        <button class="btn btn-primary ok" loc="{ concat(@i18nBase, '.yes') }">Yes</button>
        <button class="btn" data-dismiss="modal" aria-hidden="true" loc="{ concat(@i18nBase, '.no') }">No</button>
      </div>
    </div>
  </xsl:template>

  <!-- Direct version (no confirmation dialog because not in .modal div) -->
  <xsl:template match="AutoExec[@Mode = 'direct']">
    <div id="{@Id}" style="display:none"
         data-command="autoexec" data-exec="{Forward/@Command}" data-exec-target="{Forward/text()}">
       <xsl:if test="Forward/@EventTarget">
         <xsl:attribute name="data-exec-event-target"><xsl:value-of select="Forward/@EventTarget"/></xsl:attribute>
       </xsl:if>
     </div>
  </xsl:template>

  <!--**********************************-->
  <!--*****  Annexes pane content  *****-->
  <!--**********************************-->

  <xsl:template match="Annexes">
    <xsl:if test="not(Annex)">
      <p id="c-no-annex" loc="app.noAnnex">Pas d'annexe</p>
    </xsl:if>
    <table>
      <xsl:apply-templates select="." mode="class"/>
      <thead>
        <tr class="header">
          <th loc="term.date">Date</th>
          <th loc="term.activityStatus">Statut de l'activité</th>
          <th loc="term.filename">Nom du fichier</th>
          <th loc="term.sender">Expéditeur</th>
          <th loc="action.action">Action</th>
        </tr>
      </thead>
      <tbody id="c-annex-list" data-command="c-delannexe" data-confirm-loc="confirm.annex.delete" >
        <xsl:apply-templates select="Annex">
           <xsl:sort select="Date/@SortKey" order="descending"/>
        </xsl:apply-templates>
      </tbody>
    </table>
  </xsl:template>

  <!-- empty list -->
  <xsl:template match="Annexes" mode="class">
    <xsl:attribute name="class">table table-bordered c-empty</xsl:attribute>
  </xsl:template>

  <!-- not empty list -->
  <xsl:template match="Annexes[Annex]" mode="class">
    <xsl:attribute name="class">table table-bordered</xsl:attribute>
  </xsl:template>

  <xsl:template match="Annex">
    <tr>
      <td>
        <xsl:call-template name="format-text"><xsl:with-param name="text"><xsl:value-of select="Date"/></xsl:with-param></xsl:call-template>
      </td>
      <td>
        <xsl:call-template name="format-text"><xsl:with-param name="text"><xsl:value-of select="ActivityStatus"/></xsl:with-param></xsl:call-template>
      </td>
      <td>
        <xsl:apply-templates select="File"/>
      </td>
      <td>
        <xsl:call-template name="format-text"><xsl:with-param name="text"><xsl:value-of select="Sender"/></xsl:with-param></xsl:call-template>
      </td>
      <td>
        <xsl:apply-templates select="File" mode="delete"/>
      </td>
    </tr>
  </xsl:template>

  <xsl:template match="File">
      <a class="c-annex-link" target="_blank" href="{@href}">
        <xsl:value-of select="."/>
      </a>
  </xsl:template>

  <!-- no upload (hence no delete) right -->
  <xsl:template match="File" mode="delete">
    <xsl:text>-</xsl:text>
  </xsl:template>

  <!-- upload (hence delete) right -->
  <xsl:template match="File[@Del = '1']" mode="delete">
    <i data-file="{.}" class="icon-trash"></i>
  </xsl:template>

  <!-- Prints text param or a dash - if empty -->
  <xsl:template name="format-text">
    <xsl:param name="text"/>
    <xsl:choose>
      <xsl:when test="$text != ''"><xsl:value-of select="$text"/></xsl:when>
      <xsl:otherwise>-</xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="text"/>
  </xsl:template>

  <!--**********************************-->
  <!--*****  Reports pane content  *****-->
  <!--**********************************-->

  <!-- NOTE: alternatively we could use a data-command="save c-inhibit" submission once data-replace-target="open" (to open a new window) will be available in AXEL-FORMS -->
  <xsl:template match="Reports">
    <p class="text-info" loc="reports.hint">Sélectionnez une ou plusieurs rubriques à inclure puis cliquez sur
      “Imprimer” pour ouvrir le rapport prêt à imprimer dans une nouvelle fenêtre</p>
    <div id="c-report-form" style="width: 220px" data-template="#">
      <fieldgroup class="c-report-box">
        <legend loc="reports.label.categories">Rubriques</legend>
        <xsl:apply-templates select="Sections"/>
      </fieldgroup>
    </div>
    <button class="btn btn-primary"
      data-command="submit" data-form="c-report-generator"
      data-target="c-report-form"
      loc="action.print">Imprimer</button>
    <form id="c-report-generator" enctype="multipart/form-data" accept-charset="UTF-8"
      action="{/Display/Activity/No}/report" method="post" target="_blank" style="display:none">
      <input type="hidden" name="data"/>
    </form>
  </xsl:template>

  <!-- currently it is only possible to pre-select only on checkbox at a time -->
  <xsl:template match="Sections">
    <xt:use types="choice" label="Sections"
      param="appearance=full;xvalue=Section;multiple=yes;class=c-report-box"
      values="{Values}" i18n="{Labels}">1</xt:use>
  </xsl:template>

  <!-- same as above with noedit=true -->
  <xsl:template match="Sections[string(Values/@Count) = '1']">
    <xt:use types="choice" label="Sections"
      param="appearance=full;xvalue=Section;multiple=yes;class=c-report-box;noedit=true"
      values="{Values}" i18n="{Labels}">1</xt:use>
  </xsl:template>


  <!--**********************************-->
  <!--****  Contract pane content  *****-->
  <!--**********************************-->

  <xsl:template match="Contract">
    <a class="btn btn-primary" href="{/Display/Activity/No}/contract" target="_blank" loc="action.print">Imprimer</a>
  </xsl:template>

  <!--**********************************-->
  <!--*****  Alerts pane content   *****-->
  <!--**********************************-->

  <xsl:template match="AlertsList">
    <table>
      <xsl:apply-templates select="." mode="class"/>
      <thead>
        <xsl:if test="@Id">
          <xsl:attribute name="data-command">header</xsl:attribute>
          <xsl:attribute name="data-target"><xsl:value-of select="concat('c-editor-', parent::Tab/@Id)"/></xsl:attribute>
          <xsl:attribute name="data-counter"><xsl:value-of select="concat('c-counter-', parent::Tab/@Id)"/></xsl:attribute>
        </xsl:if>
        <xsl:if test="parent::Tab/@ExtraFeed">
          <xsl:attribute name="data-event-target"><xsl:value-of select="concat('c-editor-', parent::Tab/@ExtraFeed)"/></xsl:attribute>
        </xsl:if>
        <tr>
          <xsl:apply-templates select="." mode="header"/>
          <th loc="term.date">Date</th>
          <th loc="term.activityStatus">Statut de l'activité</th>
          <th loc="term.subject">Sujet</th>
          <th loc="term.author">Expéditeur</th>
          <th loc="term.addressees">Destinataire(s)</th>
        </tr>
      </thead>
      <tbody>
        <xsl:if test="@Id">
          <xsl:attribute name="id"><xsl:value-of select="string(@Id)"/></xsl:attribute>          
        </xsl:if>
        <!-- <xsl:appy-templates select="@Id"/> -->
        <xsl:apply-templates select="Alert"/>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="AlertsList[Alert]" mode="class">
    <xsl:attribute name="class">table table-bordered</xsl:attribute>
  </xsl:template>

  <xsl:template match="AlertsList[not(Alert)]" mode="class">
    <xsl:attribute name="class">table table-bordered c-empty</xsl:attribute>
  </xsl:template>

  <xsl:template match="AlertsList" mode="header">
    <xsl:attribute name="class">header</xsl:attribute>
  </xsl:template>

  <xsl:template match="AlertsList[@Workflow = 'Case']" mode="header">
    <xsl:attribute name="class">header case</xsl:attribute>
  </xsl:template>

  <xsl:template match="Alert">
    <tr>
      <td>
        <xsl:value-of select="Date"/>
      </td>
      <td>
        <xsl:value-of select="ActivityStatus"/>
      </td>
      <td>
        <a data-toggle="modal" href="{ancestor::success/@rebase}{@Base}/alerts/{Id}.modal" data-target="#c-alert-details-modal"><xsl:value-of select="Subject"/></a>
      </td>
      <td>
        <xsl:apply-templates select="Sender" mode="alert"/>
      </td>
      <td>
        <xsl:value-of select="To"/>
        <xsl:if test="To and Addressees">
          <xsl:text>, </xsl:text>
        </xsl:if>
        <xsl:value-of select="Addressees"/>
      </td>
    </tr>
  </xsl:template>

  <xsl:template match="Sender" mode="alert"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Sender[@Mode = 'batch']" mode="alert">case tracker batch
  </xsl:template>

  <!-- <xsl:template match="Sender[. != ''][../From]" mode="alert"><xsl:value-of select="../From"/> (triggered by <xsl:value-of select="."/>)
  </xsl:template> -->

  <xsl:template match="Sender[. = ''][not(../To)]" mode="alert"><i>unregistered user</i>
  </xsl:template>

  <xsl:template match="Sender[@Mode = 'auto']" mode="alert">case tracker reminder
  </xsl:template>

  <!--**********************************-->
  <!--*****  Opinion pane content  *****-->
  <!--**********************************-->

  <xsl:template match="OtherOpinions">
    <table id="{@Id}" class="table table-bordered">
      <thead>
        <tr>
          <th loc="term.date">Date</th>
          <th loc="term.author">Auteur</th>
          <th loc="term.comment">Commentaire</th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="OtherOpinion"/>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="OtherOpinion">
    <tr>
      <td>
        <xsl:value-of select="Date"/>
      </td>
      <td>
        <xsl:value-of select="Author"/>
      </td>
      <td>
        <xsl:value-of select="Comment"/>
      </td>
    </tr>
  </xsl:template>

  <!--**********************************-->
  <!--*****  LogBook pane content  *****-->
  <!--**********************************-->

  <!-- DEPRECATED -->
  <xsl:template match="Logbook">
    <table id="{@Id}" class="table table-bordered">
      <xsl:if test="(count(LogbookItem) = 0) or (count(LogbookItem/@Delete[ . = 'yes']) > 0)">
        <xsl:attribute name="data-confirm-loc">confirm.logbookItem.delete</xsl:attribute>
        <xsl:attribute name="data-command">c-dellogbook</xsl:attribute>
        <xsl:attribute name="data-controller"><xsl:value-of select="concat(/Display/Activity/No/text(), '/logbook')"/></xsl:attribute>
      </xsl:if>
      <thead>
        <tr>
          <xsl:if test="(count(LogbookItem) = 0) or (count(LogbookItem/@Delete[ . = 'yes']) > 0)"><th/></xsl:if>
          <th loc="term.date">Date</th>
          <th loc="term.coach">Coach</th>
          <th loc="term.nbOfHours">Nb d'heures</th>
          <th loc="term.expenses">Défraiements</th>
          <th loc="term.comment">Commentaire</th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="LogbookItem"/>
      </tbody>
    </table>
  </xsl:template>

  <!-- DEPRECATED -->
  <xsl:template match="LogbookItem">
    <tr>
      <xsl:copy-of select="@data-id"/>
      <xsl:if test="@Delete[ . = 'yes']">
        <th>
          <i class="icon-trash" tooltip="Supprimer"></i>
        </th>
      </xsl:if>
      <td>
        <xsl:value-of select="Date"/>
      </td>
      <td>
        <xsl:value-of select="CoachRef"/>
      </td>
      <td>
        <xsl:value-of select="NbOfHours"/>
      </td>
      <td>
        <xsl:value-of select="ExpenseAmount"/>
      </td>
      <td>
        <xsl:value-of select="Comment"/>
      </td>
    </tr>
  </xsl:template>

  <!--*************************************-->
  <!--*****  Activities pane content  *****-->
  <!--*************************************-->

  <xsl:template match="Activities">
    <table>
      <xsl:apply-templates select="." mode="class"/>
      <thead>
        <xsl:if test="Add">
          <xsl:attribute name="data-command">header</xsl:attribute>
          <xsl:attribute name="data-target">activity-editor</xsl:attribute>
        </xsl:if>
        <tr>
          <th loc="term.no">No</th>
          <th loc="term.coach">Coach</th>
          <th loc="term.creationDate">Date de création</th>
          <th loc="term.phase">Phase</th>
          <th loc="term.numberOfHours">Nombre d'heures</th>
          <th loc="term.service">Service</th>
          <th loc="term.status">Statut</th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="Activity"/>
      </tbody>
    </table>
    <xsl:apply-templates select="Legend"/>
    <!-- <xsl:if test="Add">
      <div style="text-align:center;margin-top: 40px">
        <button class="btn btn-primary" data-command="add" data-target-modal="activity-modal" data-target="activity-editor" loc="action.create.activity">Créer une activité</button>
      </div>
      <div style="margin: 25px 40px">
        <xsl:apply-templates select="Add/Legend"/>
      </div>
    </xsl:if> -->
  </xsl:template>

  <xsl:template match="Activities[Activity]" mode="class">
    <xsl:attribute name="class">table table-bordered</xsl:attribute>
  </xsl:template>

  <xsl:template match="Activities[not(Activity)]" mode="class">
    <xsl:attribute name="class">table table-bordered c-empty</xsl:attribute>
  </xsl:template>

  <xsl:template match="Legend">
    <p class="text-info">
      <xsl:copy-of select="@class"/>
      <xsl:copy-of select="text()|*"/>
    </p>
  </xsl:template>

  <!--**************************-->
  <!--*****  Shared Rules  *****-->
  <!--**************************-->

  <!-- Id attribute converstion to id attribute -->
  <xsl:template match="@Id">
    <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="*|@*|text()">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
