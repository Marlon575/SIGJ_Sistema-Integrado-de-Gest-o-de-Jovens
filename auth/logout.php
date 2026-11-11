<?php
require_once __DIR__.'/../config/bootstrap.php';
requireAuth();
if($_SERVER['REQUEST_METHOD']!=='POST'){http_response_code(405);header('Allow: POST');exit('Use o botão Terminar sessão.');}
verifyCsrf();
$_SESSION=[];
if(ini_get('session.use_cookies')){$params=session_get_cookie_params();setcookie(session_name(),'',time()-42000,$params['path'],$params['domain']??'',$params['secure'],$params['httponly']);}
session_destroy();
header('Location: /auth/login.php');exit;