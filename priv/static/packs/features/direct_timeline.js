(window.webpackJsonp=window.webpackJsonp||[]).push([[21],{837:function(e,t,n){"use strict";n.r(t),n.d(t,"default",(function(){return Z}));var a,o,s,c=n(0),i=n(2),r=(n(9),n(6),n(8)),l=n(1),d=n(3),u=n.n(d),p=n(15),h=n(762),f=n(759),b=n(107),m=n(253),v=n(7),j=n(766),O=n(10),g=n(32),M=n(65),y=n.n(M),_=n(5),w=n.n(_),C=n(16),k=n.n(C),R=n(21),I=n(234),L=n(282),x=n(723),D=n(780),S=n(300),E=n(53),N=n(109),U=n(301),T=n(22),H=n(14),A=n.n(H);var q=Object(v.f)({more:{id:"status.more",defaultMessage:"More"},open:{id:"conversation.open",defaultMessage:"View conversation"},reply:{id:"status.reply",defaultMessage:"Reply"},markAsRead:{id:"conversation.mark_as_read",defaultMessage:"Mark as read"},delete:{id:"conversation.delete",defaultMessage:"Delete conversation"},muteConversation:{id:"status.mute_conversation",defaultMessage:"Mute conversation"},unmuteConversation:{id:"status.unmute_conversation",defaultMessage:"Unmute conversation"}}),P=Object(v.g)((s=o=function(e){Object(r.a)(n,e);var t;t=n;function n(){for(var t,n=arguments.length,a=new Array(n),o=0;o<n;o++)a[o]=arguments[o];return t=e.call.apply(e,[this].concat(a))||this,Object(l.a)(Object(i.a)(t),"handleEmojiMouseEnter",(function(e){var t=e.target;t.src=t.getAttribute("data-original")})),Object(l.a)(Object(i.a)(t),"handleEmojiMouseLeave",(function(e){var t=e.target;t.src=t.getAttribute("data-static")})),Object(l.a)(Object(i.a)(t),"handleClick",(function(){if(t.context.router){var e=t.props,n=e.lastStatus,a=e.unread,o=e.markRead;a&&o(),t.context.router.history.push("/statuses/"+n.get("id"))}})),Object(l.a)(Object(i.a)(t),"handleMarkAsRead",(function(){t.props.markRead()})),Object(l.a)(Object(i.a)(t),"handleReply",(function(){t.props.reply(t.props.lastStatus,t.context.router.history)})),Object(l.a)(Object(i.a)(t),"handleDelete",(function(){t.props.delete()})),Object(l.a)(Object(i.a)(t),"handleHotkeyMoveUp",(function(){t.props.onMoveUp(t.props.conversationId)})),Object(l.a)(Object(i.a)(t),"handleHotkeyMoveDown",(function(){t.props.onMoveDown(t.props.conversationId)})),Object(l.a)(Object(i.a)(t),"handleConversationMute",(function(){t.props.onMute(t.props.lastStatus)})),Object(l.a)(Object(i.a)(t),"handleShowMore",(function(){t.props.onToggleHidden(t.props.lastStatus)})),Object(l.a)(Object(i.a)(t),"setNamesRef",(function(e){t.namesNode=e})),t}var a=n.prototype;return a._updateEmojis=function(){var e=this.namesNode;if(e&&!T.a)for(var t=e.querySelectorAll(".custom-emoji"),n=0;n<t.length;n++){var a=t[n];a.classList.contains("status-emoji")||(a.classList.add("status-emoji"),a.addEventListener("mouseenter",this.handleEmojiMouseEnter,!1),a.addEventListener("mouseleave",this.handleEmojiMouseLeave,!1))}},a.componentDidMount=function(){this._updateEmojis()},a.componentDidUpdate=function(){this._updateEmojis()},a.render=function(){var e=this.props,t=e.accounts,n=e.lastStatus,a=e.unread,o=e.intl;if(null===n)return null;var s=[{text:o.formatMessage(q.open),action:this.handleClick},null];s.push({text:o.formatMessage(n.get("muted")?q.unmuteConversation:q.muteConversation),action:this.handleConversationMute}),a&&(s.push({text:o.formatMessage(q.markAsRead),action:this.handleMarkAsRead}),s.push(null)),s.push({text:o.formatMessage(q.delete),action:this.handleDelete});var i=t.map((function(e){return Object(c.a)(S.a,{to:"/accounts/"+e.get("id"),href:e.get("url"),title:e.get("acct")},e.get("id"),Object(c.a)("bdi",{},void 0,Object(c.a)("strong",{className:"display-name__html",dangerouslySetInnerHTML:{__html:e.get("display_name_html")}})))})).reduce((function(e,t){return[e,", ",t]})),r={reply:this.handleReply,open:this.handleClick,moveUp:this.handleHotkeyMoveUp,moveDown:this.handleHotkeyMoveDown,toggleHidden:this.handleShowMore};return Object(c.a)(U.HotKeys,{handlers:r},void 0,Object(c.a)("div",{className:A()("conversation focusable muted",{"conversation--unread":a}),tabIndex:"0"},void 0,Object(c.a)("div",{className:"conversation__avatar",onClick:this.handleClick,role:"presentation"},void 0,Object(c.a)(D.a,{accounts:t,size:48})),Object(c.a)("div",{className:"conversation__content"},void 0,Object(c.a)("div",{className:"conversation__content__info"},void 0,Object(c.a)("div",{className:"conversation__content__relative-time"},void 0,a&&Object(c.a)("span",{className:"conversation__unread"})," ",Object(c.a)(N.default,{timestamp:n.get("created_at")})),u.a.createElement("div",{className:"conversation__content__names",ref:this.setNamesRef},Object(c.a)(v.b,{id:"conversation.with",defaultMessage:"With {names}",values:{names:Object(c.a)("span",{},void 0,i)}}))),Object(c.a)(I.a,{status:n,onClick:this.handleClick,expanded:!n.get("hidden"),onExpandedToggle:this.handleShowMore,collapsable:!0}),n.get("media_attachments").size>0&&Object(c.a)(L.a,{compact:!0,media:n.get("media_attachments")}),Object(c.a)("div",{className:"status__action-bar"},void 0,Object(c.a)(E.a,{className:"status__action-bar-button",title:o.formatMessage(q.reply),icon:"reply",onClick:this.handleReply}),Object(c.a)("div",{className:"status__action-bar-dropdown"},void 0,Object(c.a)(x.a,{status:n,items:s,icon:"ellipsis-h",size:18,direction:"right",title:o.formatMessage(q.more)}))))))},n}(R.a),Object(l.a)(o,"contextTypes",{router:w.a.object}),Object(l.a)(o,"propTypes",{conversationId:w.a.string.isRequired,accounts:k.a.list.isRequired,lastStatus:k.a.map,unread:w.a.bool.isRequired,onMoveUp:w.a.func,onMoveDown:w.a.func,markRead:w.a.func.isRequired,delete:w.a.func.isRequired,intl:w.a.object.isRequired}),a=s))||a,z=n(210),K=n(23),V=n(48),W=n(89),J=Object(v.f)({replyConfirm:{id:"confirmations.reply.confirm",defaultMessage:"Reply"},replyMessage:{id:"confirmations.reply.message",defaultMessage:"Replying now will overwrite the message you are currently composing. Are you sure you want to proceed?"}}),F=Object(v.g)(Object(p.connect)((function(){var e=Object(z.f)();return function(t,n){var a=n.conversationId,o=t.getIn(["conversations","items"]).find((function(e){return e.get("id")===a})),s=o.get("last_status",null);return{accounts:o.get("accounts").map((function(e){return t.getIn(["accounts",e],null)})),unread:o.get("unread"),lastStatus:s&&e(t,{id:s})}}}),(function(e,t){var n=t.intl,a=t.conversationId;return{markRead:function(){e(Object(b.k)(a))},reply:function(t,a){e((function(o,s){0!==s().getIn(["compose","text"]).trim().length?e(Object(V.d)("CONFIRM",{message:n.formatMessage(J.replyMessage),confirm:n.formatMessage(J.replyConfirm),onConfirm:function(){return e(Object(K.gb)(t,a))}})):e(Object(K.gb)(t,a))}))},delete:function(){e(Object(b.i)(a))},onMute:function(t){t.get("muted")?e(Object(W.n)(t.get("id"))):e(Object(W.k)(t.get("id")))},onToggleHidden:function(t){t.get("hidden")?e(Object(W.l)(t.get("id"))):e(Object(W.j)(t.get("id")))}}}))(P)),Y=n(1049);var B=function(e){Object(r.a)(n,e);var t;t=n;function n(){for(var t,n=arguments.length,a=new Array(n),o=0;o<n;o++)a[o]=arguments[o];return t=e.call.apply(e,[this].concat(a))||this,Object(l.a)(Object(i.a)(t),"getCurrentIndex",(function(e){return t.props.conversations.findIndex((function(t){return t.get("id")===e}))})),Object(l.a)(Object(i.a)(t),"handleMoveUp",(function(e){var n=t.getCurrentIndex(e)-1;t._selectChild(n,!0)})),Object(l.a)(Object(i.a)(t),"handleMoveDown",(function(e){var n=t.getCurrentIndex(e)+1;t._selectChild(n,!1)})),Object(l.a)(Object(i.a)(t),"setRef",(function(e){t.node=e})),Object(l.a)(Object(i.a)(t),"handleLoadOlder",y()((function(){var e=t.props.conversations.last();e&&e.get("last_status")&&t.props.onLoadMore(e.get("last_status"))}),300,{leading:!0})),t}var a=n.prototype;return a._selectChild=function(e,t){var n=this.node.node,a=n.querySelector("article:nth-of-type("+(e+1)+") .focusable");a&&(t&&n.scrollTop>a.offsetTop?a.scrollIntoView(!0):!t&&n.scrollTop+n.clientHeight<a.offsetTop+a.offsetHeight&&a.scrollIntoView(!1),a.focus())},a.render=function(){var e=this,t=this.props,n=t.conversations,a=t.onLoadMore,o=Object(g.default)(t,["conversations","onLoadMore"]);return u.a.createElement(Y.a,Object(O.default)({},o,{onLoadMore:a&&this.handleLoadOlder,scrollKey:"direct",ref:this.setRef}),n.map((function(t){return Object(c.a)(F,{conversationId:t.get("id"),onMoveUp:e.handleMoveUp,onMoveDown:e.handleMoveDown},t.get("id"))})))},n}(R.a);Object(l.a)(B,"propTypes",{conversations:k.a.list.isRequired,hasMore:w.a.bool,isLoading:w.a.bool,onLoadMore:w.a.func,shouldUpdateScroll:w.a.func});var G,Q=Object(p.connect)((function(e){return{conversations:e.getIn(["conversations","items"]),isLoading:e.getIn(["conversations","isLoading"],!0),hasMore:e.getIn(["conversations","hasMore"],!1)}}),(function(e){return{onLoadMore:function(t){return e(Object(b.j)({maxId:t}))}}}))(B);var X=Object(v.f)({title:{id:"column.direct",defaultMessage:"Direct messages"}}),Z=Object(p.connect)()(G=Object(v.g)(G=function(e){Object(r.a)(n,e);var t;t=n;function n(){for(var t,n=arguments.length,a=new Array(n),o=0;o<n;o++)a[o]=arguments[o];return t=e.call.apply(e,[this].concat(a))||this,Object(l.a)(Object(i.a)(t),"handlePin",(function(){var e=t.props,n=e.columnId,a=e.dispatch;a(n?Object(m.h)(n):Object(m.e)("DIRECT",{}))})),Object(l.a)(Object(i.a)(t),"handleMove",(function(e){var n=t.props,a=n.columnId;(0,n.dispatch)(Object(m.g)(a,e))})),Object(l.a)(Object(i.a)(t),"handleHeaderClick",(function(){t.column.scrollTop()})),Object(l.a)(Object(i.a)(t),"setRef",(function(e){t.column=e})),Object(l.a)(Object(i.a)(t),"handleLoadMore",(function(e){t.props.dispatch(Object(b.j)({maxId:e}))})),t}var a=n.prototype;return a.componentDidMount=function(){var e=this.props.dispatch;e(Object(b.l)()),e(Object(b.j)()),this.disconnect=e(Object(j.b)())},a.componentWillUnmount=function(){this.props.dispatch(Object(b.m)()),this.disconnect&&(this.disconnect(),this.disconnect=null)},a.render=function(){var e=this.props,t=e.intl,n=e.hasUnread,a=e.columnId,o=e.multiColumn,s=e.shouldUpdateScroll,i=!!a;return u.a.createElement(h.a,{bindToDocument:!o,ref:this.setRef,label:t.formatMessage(X.title)},Object(c.a)(f.a,{icon:"envelope",active:n,title:t.formatMessage(X.title),onPin:this.handlePin,onMove:this.handleMove,onClick:this.handleHeaderClick,pinned:i,multiColumn:o}),Object(c.a)(Q,{trackScroll:!i,scrollKey:"direct_timeline-"+a,timelineId:"direct",onLoadMore:this.handleLoadMore,emptyMessage:Object(c.a)(v.b,{id:"empty_column.direct",defaultMessage:"You don't have any direct messages yet. When you send or receive one, it will show up here."}),shouldUpdateScroll:s}))},n}(u.a.PureComponent))||G)||G}}]);
//# sourceMappingURL=direct_timeline.js.map