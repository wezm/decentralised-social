// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"
import "phoenix"
import { Ajax } from "phoenix"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"
window.onload = function () {
  let endpointUrlEl = document.getElementById('config_form_endpoint_url')
  if (endpointUrlEl) {
    endpointUrlEl.addEventListener('change', function (evt) {
      let endpointUrl = new URL(endpointUrlEl.value);

      let adminEmailEl = document.getElementById('config_form_instance_email');
      if (adminEmailEl.value == '') {
        adminEmailEl.value = 'admin@' + endpointUrl.hostname;
      }

      let adminUserEmailEl = document.getElementById('config_form_admin_email');
      if (adminUserEmailEl.value == '') {
        adminUserEmailEl.value = 'admin@' + endpointUrl.hostname;
      }

      let notifyEmailEl = document.getElementById('config_form_instance_notify_email');
      if (notifyEmailEl.value == '') {
        notifyEmailEl.value = 'no-reply@' + endpointUrl.hostname;
      }
    });
  }

  let migrations = document.getElementById('migrations')

  if (migrations) {
    Ajax.request("GET", "/run_migrations", "application/json", "", 20000, show_error, (resp) => {
      if (resp == "ok") {
        window.location = "/config";
      } else {
        show_error();
      }
    });
  }
}

function show_error() {
  let errorEl = document.getElementById('error');
  errorEl.style.visibility = 'visible';
}
