(window.webpackJsonp=window.webpackJsonp||[]).push([[61],{775:function(t,e,a){"use strict";a.r(e),a.d(e,"default",(function(){return C}));var n,o,s,i=a(0),c=a(2),u=a(7),r=a(1),l=a(62),d=a.n(l),h=a(3),b=a.n(h),p=a(13),f=a(5),j=a.n(f),m=a(14),O=a.n(m),g=a(201),v=a(730),M=a(732),I=a(249),w=a(1037),y=a(6),L=a(18),k=Object(y.f)({heading:{id:"column.favourites",defaultMessage:"Favourites"}}),C=Object(p.connect)((function(t){return{statusIds:t.getIn(["status_lists","favourites","items"]),isLoading:t.getIn(["status_lists","favourites","isLoading"],!0),hasMore:!!t.getIn(["status_lists","favourites","next"])}}))(n=Object(y.g)((s=o=function(t){function e(){for(var e,a=arguments.length,n=new Array(a),o=0;o<a;o++)n[o]=arguments[o];return e=t.call.apply(t,[this].concat(n))||this,Object(r.a)(Object(c.a)(e),"handlePin",(function(){var t=e.props,a=t.columnId,n=t.dispatch;n(a?Object(I.h)(a):Object(I.e)("FAVOURITES",{}))})),Object(r.a)(Object(c.a)(e),"handleMove",(function(t){var a=e.props,n=a.columnId;(0,a.dispatch)(Object(I.g)(n,t))})),Object(r.a)(Object(c.a)(e),"handleHeaderClick",(function(){e.column.scrollTop()})),Object(r.a)(Object(c.a)(e),"setRef",(function(t){e.column=t})),Object(r.a)(Object(c.a)(e),"handleLoadMore",d()((function(){e.props.dispatch(Object(g.g)())}),300,{leading:!0})),e}Object(u.a)(e,t);var a=e.prototype;return a.componentWillMount=function(){this.props.dispatch(Object(g.h)())},a.render=function(){var t=this.props,e=t.intl,a=t.statusIds,n=t.columnId,o=t.multiColumn,s=t.hasMore,c=t.isLoading,u=!!n,r=Object(i.a)(y.b,{id:"empty_column.favourited_statuses",defaultMessage:"You don't have any favourite toots yet. When you favourite one, it will show up here."});return b.a.createElement(v.a,{bindToDocument:!o,ref:this.setRef,name:"favourites",label:e.formatMessage(k.heading)},Object(i.a)(M.a,{icon:"star",title:e.formatMessage(k.heading),onPin:this.handlePin,onMove:this.handleMove,onClick:this.handleHeaderClick,pinned:u,multiColumn:o,showBackButton:!0}),Object(i.a)(w.a,{trackScroll:!u,statusIds:a,scrollKey:"favourited_statuses-"+n,hasMore:s,isLoading:c,onLoadMore:this.handleLoadMore,emptyMessage:r,bindToDocument:!o}))},e}(L.a),Object(r.a)(o,"propTypes",{dispatch:j.a.func.isRequired,statusIds:O.a.list.isRequired,intl:j.a.object.isRequired,columnId:j.a.string,multiColumn:j.a.bool,hasMore:j.a.bool,isLoading:j.a.bool}),n=s))||n)||n}}]);
//# sourceMappingURL=favourited_statuses.js.map