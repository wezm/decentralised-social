(window.webpackJsonp=window.webpackJsonp||[]).push([[243],{853:function(e,t,a){"use strict";a.r(t),a.d(t,"default",(function(){return T}));var n=a(0),o=a(2),i=(a(9),a(6),a(8)),r=a(1),s=a(3),c=a.n(s),d=a(15),l=a(105),u=a(36),b=a(5),p=a.n(b),h=a(16),g=a.n(h),m=a(210),v=a(7),O=a(307),j=a.n(O),f=a(1154),w=a.n(f),_=a(234),y=a(42),C=a(318);var k,M,I,N=function(e){Object(i.a)(a,e);var t;t=a;function a(){return e.apply(this,arguments)||this}return a.prototype.render=function(){var e=this.props,t=e.status,a=e.checked,o=e.onToggle,i=e.disabled,r=null;if(t.get("reblog"))return null;if(t.get("media_attachments").size>0)if(t.get("media_attachments").some((function(e){return"unknown"===e.get("type")})));else if("video"===t.getIn(["media_attachments",0,"type"])){var s=t.getIn(["media_attachments",0]);r=Object(n.a)(C.a,{fetchComponent:y.M,loading:this.renderLoadingVideoPlayer},void 0,(function(e){return Object(n.a)(e,{preview:s.get("preview_url"),blurhash:s.get("blurhash"),src:s.get("url"),alt:s.get("description"),width:239,height:110,inline:!0,sensitive:t.get("sensitive"),onOpenVideo:w.a})}))}else r=Object(n.a)(C.a,{fetchComponent:y.B,loading:this.renderLoadingMediaGallery},void 0,(function(e){return Object(n.a)(e,{media:t.get("media_attachments"),sensitive:t.get("sensitive"),height:110,onOpenMedia:w.a})}));return(Object(n.a)("div",{className:"status-check-box"},void 0,Object(n.a)("div",{className:"status-check-box__status"},void 0,Object(n.a)(_.a,{status:t}),r),Object(n.a)("div",{className:"status-check-box-toggle"},void 0,Object(n.a)(j.a,{checked:a,onChange:o,disabled:i}))))},a}(c.a.PureComponent),S=a(4),x=Object(d.connect)((function(e,t){var a=t.id;return{status:e.getIn(["statuses",a]),checked:e.getIn(["reports","new","status_ids"],Object(S.Set)()).includes(a)}}),(function(e,t){var a=t.id;return{onToggle:function(t){e(Object(l.m)(a,t.target.checked))}}}))(N),R=a(21),q=a(110),F=a(53);var K=Object(v.f)({close:{id:"lightbox.close",defaultMessage:"Close"},placeholder:{id:"report.placeholder",defaultMessage:"Additional comments"},submit:{id:"report.submit",defaultMessage:"Submit"}}),T=Object(d.connect)((function(){var e=Object(m.d)();return function(t){var a=t.getIn(["reports","new","account_id"]);return{isSubmitting:t.getIn(["reports","new","isSubmitting"]),account:e(t,a),comment:t.getIn(["reports","new","comment"]),forward:t.getIn(["reports","new","forward"]),statusIds:Object(S.OrderedSet)(t.getIn(["timelines","account:"+a+":with_replies","items"])).union(t.getIn(["reports","new","status_ids"]))}}}))(k=Object(v.g)((I=M=function(e){Object(i.a)(a,e);var t;t=a;function a(){for(var t,a=arguments.length,n=new Array(a),i=0;i<a;i++)n[i]=arguments[i];return t=e.call.apply(e,[this].concat(n))||this,Object(r.a)(Object(o.a)(t),"handleCommentChange",(function(e){t.props.dispatch(Object(l.i)(e.target.value))})),Object(r.a)(Object(o.a)(t),"handleForwardChange",(function(e){t.props.dispatch(Object(l.j)(e.target.checked))})),Object(r.a)(Object(o.a)(t),"handleSubmit",(function(){t.props.dispatch(Object(l.l)())})),Object(r.a)(Object(o.a)(t),"handleKeyDown",(function(e){13===e.keyCode&&(e.ctrlKey||e.metaKey)&&t.handleSubmit()})),t}var s=a.prototype;return s.componentDidMount=function(){this.props.dispatch(Object(u.q)(this.props.account.get("id"),{withReplies:!0}))},s.componentWillReceiveProps=function(e){this.props.account!==e.account&&e.account&&this.props.dispatch(Object(u.q)(e.account.get("id"),{withReplies:!0}))},s.render=function(){var e=this.props,t=e.account,a=e.comment,o=e.intl,i=e.statusIds,r=e.isSubmitting,s=e.forward,c=e.onClose;if(!t)return null;var d=t.get("acct").split("@")[1];return(Object(n.a)("div",{className:"modal-root__modal report-modal"},void 0,Object(n.a)("div",{className:"report-modal__target"},void 0,Object(n.a)(F.a,{className:"media-modal__close",title:o.formatMessage(K.close),icon:"times",onClick:c,size:16}),Object(n.a)(v.b,{id:"report.target",defaultMessage:"Report {target}",values:{target:Object(n.a)("strong",{},void 0,t.get("acct"))}})),Object(n.a)("div",{className:"report-modal__container"},void 0,Object(n.a)("div",{className:"report-modal__comment"},void 0,Object(n.a)("p",{},void 0,Object(n.a)(v.b,{id:"report.hint",defaultMessage:"The report will be sent to your server moderators. You can provide an explanation of why you are reporting this account below:"})),Object(n.a)("textarea",{className:"setting-text light",placeholder:o.formatMessage(K.placeholder),value:a,onChange:this.handleCommentChange,onKeyDown:this.handleKeyDown,disabled:r,autoFocus:!0}),d&&Object(n.a)("div",{},void 0,Object(n.a)("p",{},void 0,Object(n.a)(v.b,{id:"report.forward_hint",defaultMessage:"The account is from another server. Send an anonymized copy of the report there as well?"})),Object(n.a)("div",{className:"setting-toggle"},void 0,Object(n.a)(j.a,{id:"report-forward",checked:s,disabled:r,onChange:this.handleForwardChange}),Object(n.a)("label",{htmlFor:"report-forward",className:"setting-toggle__label"},void 0,Object(n.a)(v.b,{id:"report.forward",defaultMessage:"Forward to {target}",values:{target:d}})))),Object(n.a)(q.a,{disabled:r,text:o.formatMessage(K.submit),onClick:this.handleSubmit})),Object(n.a)("div",{className:"report-modal__statuses"},void 0,Object(n.a)("div",{},void 0,i.map((function(e){return Object(n.a)(x,{id:e,disabled:r},e)})))))))},a}(R.a),Object(r.a)(M,"propTypes",{isSubmitting:p.a.bool,account:g.a.map,statusIds:g.a.orderedSet.isRequired,comment:p.a.string.isRequired,forward:p.a.bool,dispatch:p.a.func.isRequired,intl:p.a.object.isRequired}),k=I))||k)||k}}]);
//# sourceMappingURL=report_modal.js.map