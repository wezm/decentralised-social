(window.webpackJsonp=window.webpackJsonp||[]).push([[50],{833:function(e,t,a){"use strict";a.r(t);var n=a(0),o=a(2),i=a(7),c=a(1),s=a(3),r=a.n(s),l=a(13),d=a(14),p=a.n(d),u=a(5),h=a.n(u),b=a(22),m=a(32),O=a(299),g=a(730),f=a(1052),j=a(18),v=a(103),y=a(211),_=a(12),I=a.n(_),M=a(23),L=a(16),w=a(149),C=function(e){function t(){for(var t,a=arguments.length,n=new Array(a),i=0;i<a;i++)n[i]=arguments[i];return t=e.call.apply(e,[this].concat(n))||this,Object(c.a)(Object(o.a)(t),"state",{visible:"hide_all"!==L.g&&!t.props.attachment.getIn(["status","sensitive"])||"show_all"===L.g,loaded:!1}),Object(c.a)(Object(o.a)(t),"setCanvasRef",(function(e){t.canvas=e})),Object(c.a)(Object(o.a)(t),"handleImageLoad",(function(){t.setState({loaded:!0})})),Object(c.a)(Object(o.a)(t),"handleMouseEnter",(function(e){t.hoverToPlay()&&e.target.play()})),Object(c.a)(Object(o.a)(t),"handleMouseLeave",(function(e){t.hoverToPlay()&&(e.target.pause(),e.target.currentTime=0)})),Object(c.a)(Object(o.a)(t),"handleClick",(function(e){0!==e.button||e.ctrlKey||e.metaKey||(e.preventDefault(),t.state.visible?t.props.onOpenMedia(t.props.attachment):t.setState({visible:!0}))})),t}Object(i.a)(t,e);var a=t.prototype;return a.componentDidMount=function(){this.props.attachment.get("blurhash")&&this._decode()},a.componentDidUpdate=function(e){e.attachment.get("blurhash")!==this.props.attachment.get("blurhash")&&this.props.attachment.get("blurhash")&&this._decode()},a._decode=function(){var e=this.props.attachment.get("blurhash"),t=Object(y.decode)(e,32,32);if(t){var a=this.canvas.getContext("2d"),n=new ImageData(t,32,32);a.putImageData(n,0,0)}},a.hoverToPlay=function(){return!L.a&&-1!==["gifv","video"].indexOf(this.props.attachment.get("type"))},a.render=function(){var e=this.props,t=e.attachment,a=e.displayWidth,o=this.state,i=o.visible,c=o.loaded,s=Math.floor((a-4)/3)-4+"px",l=s,d=t.get("status"),p=d.get("spoiler_text")||t.get("description"),u="";if("unknown"===t.get("type"));else if("audio"===t.get("type"))u=Object(n.a)("span",{className:"account-gallery__item__icons"},void 0,Object(n.a)(M.a,{id:"music"}));else if("image"===t.get("type")){var h=100*((t.getIn(["meta","focus","x"])||0)/2+.5),b=100*((t.getIn(["meta","focus","y"])||0)/-2+.5);u=Object(n.a)("img",{src:t.get("preview_url"),alt:t.get("description"),title:t.get("description"),style:{objectPosition:h+"% "+b+"%"},onLoad:this.handleImageLoad})}else if(-1!==["gifv","video"].indexOf(t.get("type"))){var m=!Object(w.a)()&&L.a,O="video"===t.get("type")?Object(n.a)(M.a,{id:"play"}):"GIF";u=Object(n.a)("div",{className:I()("media-gallery__gifv",{autoplay:m})},void 0,Object(n.a)("video",{className:"media-gallery__item-gifv-thumbnail","aria-label":t.get("description"),title:t.get("description"),role:"application",src:t.get("url"),onMouseEnter:this.handleMouseEnter,onMouseLeave:this.handleMouseLeave,autoPlay:m,loop:!0,muted:!0}),Object(n.a)("span",{className:"media-gallery__gifv__label"},void 0,O))}var g=Object(n.a)("span",{className:"account-gallery__item__icons"},void 0,Object(n.a)(M.a,{id:"eye-slash"}));return Object(n.a)("div",{className:"account-gallery__item",style:{width:s,height:l}},void 0,Object(n.a)("a",{className:"media-gallery__item-thumbnail",href:d.get("url"),onClick:this.handleClick,title:p,target:"_blank",rel:"noopener noreferrer"},void 0,r.a.createElement("canvas",{width:32,height:32,ref:this.setCanvasRef,className:I()("media-gallery__preview",{"media-gallery__preview--hidden":i&&c})}),i?u:g))},t}(j.a);Object(c.a)(C,"propTypes",{attachment:p.a.map.isRequired,displayWidth:h.a.number.isRequired,onOpenMedia:h.a.func.isRequired});var R,x,k,S=a(1056),T=a(467),N=a(1051),D=a(1029),A=a(42);a.d(t,"default",(function(){return q}));var E=function(e){function t(){for(var t,a=arguments.length,n=new Array(a),i=0;i<a;i++)n[i]=arguments[i];return t=e.call.apply(e,[this].concat(n))||this,Object(c.a)(Object(o.a)(t),"handleLoadMore",(function(){t.props.onLoadMore(t.props.maxId)})),t}return Object(i.a)(t,e),t.prototype.render=function(){return Object(n.a)(N.a,{disabled:this.props.disabled,onClick:this.handleLoadMore})},t}(j.a);Object(c.a)(E,"propTypes",{maxId:h.a.string,onLoadMore:h.a.func.isRequired});var q=Object(l.connect)((function(e,t){return{isAccount:!!e.getIn(["accounts",t.params.accountId]),attachments:Object(v.a)(e,t.params.accountId),isLoading:e.getIn(["timelines","account:"+t.params.accountId+":media","isLoading"]),hasMore:e.getIn(["timelines","account:"+t.params.accountId+":media","hasMore"])}}))((k=x=function(e){function t(){for(var t,a=arguments.length,n=new Array(a),i=0;i<a;i++)n[i]=arguments[i];return t=e.call.apply(e,[this].concat(n))||this,Object(c.a)(Object(o.a)(t),"state",{width:323}),Object(c.a)(Object(o.a)(t),"handleHeaderClick",(function(){t.column.scrollTop()})),Object(c.a)(Object(o.a)(t),"handleScrollToBottom",(function(){t.props.hasMore&&t.handleLoadMore(t.props.attachments.size>0?t.props.attachments.last().getIn(["status","id"]):void 0)})),Object(c.a)(Object(o.a)(t),"handleScroll",(function(e){var a=e.target,n=a.scrollTop;150>a.scrollHeight-n-a.clientHeight&&!t.props.isLoading&&t.handleScrollToBottom()})),Object(c.a)(Object(o.a)(t),"handleLoadMore",(function(e){t.props.dispatch(Object(m.p)(t.props.params.accountId,{maxId:e}))})),Object(c.a)(Object(o.a)(t),"handleLoadOlder",(function(e){e.preventDefault(),t.handleScrollToBottom()})),Object(c.a)(Object(o.a)(t),"shouldUpdateScroll",(function(e,t){var a=t.location;return!(((e||{}).location||{}).state||{}).mastodonModalOpen&&!(a.state&&a.state.mastodonModalOpen)})),Object(c.a)(Object(o.a)(t),"setColumnRef",(function(e){t.column=e})),Object(c.a)(Object(o.a)(t),"handleOpenMedia",(function(e){if("video"===e.get("type"))t.props.dispatch(Object(A.d)("VIDEO",{media:e,status:e.get("status")}));else if("audio"===e.get("type"))t.props.dispatch(Object(A.d)("AUDIO",{media:e,status:e.get("status")}));else{var a=e.getIn(["status","media_attachments"]),n=a.findIndex((function(t){return t.get("id")===e.get("id")}));t.props.dispatch(Object(A.d)("MEDIA",{media:a,index:n,status:e.get("status")}))}})),Object(c.a)(Object(o.a)(t),"handleRef",(function(e){e&&t.setState({width:e.offsetWidth})})),t}Object(i.a)(t,e);var a=t.prototype;return a.componentDidMount=function(){this.props.dispatch(Object(b.F)(this.props.params.accountId)),this.props.dispatch(Object(m.p)(this.props.params.accountId))},a.componentWillReceiveProps=function(e){e.params.accountId!==this.props.params.accountId&&e.params.accountId&&(this.props.dispatch(Object(b.F)(e.params.accountId)),this.props.dispatch(Object(m.p)(this.props.params.accountId)))},a.render=function(){var e=this,t=this.props,a=t.attachments,o=t.isLoading,i=t.hasMore,c=t.isAccount,s=t.multiColumn,l=this.state.width;if(!c)return Object(n.a)(g.a,{},void 0,Object(n.a)(D.a,{}));if(!a&&o)return Object(n.a)(g.a,{},void 0,Object(n.a)(O.a,{}));var d=null;return!i||o&&0===a.size||(d=Object(n.a)(N.a,{visible:!o,onClick:this.handleLoadOlder})),r.a.createElement(g.a,{ref:this.setColumnRef},Object(n.a)(f.a,{onClick:this.handleHeaderClick,multiColumn:s}),Object(n.a)(T.a,{scrollKey:"account_gallery",shouldUpdateScroll:this.shouldUpdateScroll},void 0,Object(n.a)("div",{className:"scrollable scrollable--flex",onScroll:this.handleScroll},void 0,Object(n.a)(S.a,{accountId:this.props.params.accountId}),r.a.createElement("div",{role:"feed",className:"account-gallery__container",ref:this.handleRef},a.map((function(t,o){return null===t?Object(n.a)(E,{maxId:o>0?a.getIn(o-1,"id"):null,onLoadMore:e.handleLoadMore},"more:"+a.getIn(o+1,"id")):Object(n.a)(C,{attachment:t,displayWidth:l,onOpenMedia:e.handleOpenMedia},t.get("id"))})),d),o&&0===a.size&&Object(n.a)("div",{className:"scrollable__append"},void 0,Object(n.a)(O.a,{})))))},t}(j.a),Object(c.a)(x,"propTypes",{params:h.a.object.isRequired,dispatch:h.a.func.isRequired,attachments:p.a.list.isRequired,isLoading:h.a.bool,hasMore:h.a.bool,isAccount:h.a.bool,multiColumn:h.a.bool}),R=k))||R}}]);
//# sourceMappingURL=account_gallery.js.map