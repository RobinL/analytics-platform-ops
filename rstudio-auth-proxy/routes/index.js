var express = require('express');
var passport = require('passport');
var httpProxy = require('http-proxy');
var ensureLoggedIn = require('connect-ensure-login').ensureLoggedIn()
var router = express.Router();

var env = {
  AUTH0_CLIENT_ID: process.env.AUTH0_CLIENT_ID,
  AUTH0_DOMAIN: process.env.AUTH0_DOMAIN,
  AUTH0_CALLBACK_URL: process.env.AUTH0_CALLBACK_URL || 'http://localhost:3000/callback'
}

var proxy = httpProxy.createProxyServer({
  target: {
    host: process.env.SHINY_HOST,
    port: process.env.SHINY_PORT
  }
});

proxy.on('error', function(e) {
  console.log('Error connecting');
  console.log(e);
});

var setIfExists = function(proxyReq, header, value){
  if(value){
    proxyReq.setHeader(header, value);
  }
}

var emailToUsername = function(email){
  return email.toLowerCase()
    .replace(/.gov.uk$/g, '')
    .replace(/[^a-z0-9_]/g, '-')
    .slice(0, 32);
}

proxy.on('proxyReq', function(proxyReq, req, res, options) {
  setIfExists(proxyReq, 'x-auth0-nickname', req.user._json.nickname);
  setIfExists(proxyReq, 'x-auth0-user_id', req.user._json.user_id);
  setIfExists(proxyReq, 'x-auth0-email', req.user._json.email);
  setIfExists(proxyReq, 'x-auth0-name', req.user._json.name);
  setIfExists(proxyReq, 'x-auth0-picture', req.user._json.picture);
  setIfExists(proxyReq, 'x-auth0-locale', req.user._json.locale);

  setIfExists(proxyReq, 'X-RStudio-Username',
              emailToUsername(req.user._json.nickname));
});


/* Handle login */
router.get('/login',
  function(req, res){
    res.render('login', { env: env });
  }
);

/* Handle logout */
router.get('/logout', function(req, res){
  req.logout();
  res.redirect('/login');
});

/* Handle auth callback */
router.get('/callback',
  passport.authenticate('auth0', { failureRedirect: '/login' }),
  function(req, res) {
    res.redirect(req.session.returnTo || '/');
  }
);

/* Proxy RStudio login URL */
router.all('/auth-sign-in', function(req, res, next) {
  proxy.web(req, res);
});

/* Authenticate and proxy all other requests */
router.all(/.*/, ensureLoggedIn, function(req, res, next) {
  proxy.web(req, res);
});

/* GET home page. */
// router.get('/', function(req, res, next) {
//   res.redirect('/reports/');
// });



module.exports = router;
