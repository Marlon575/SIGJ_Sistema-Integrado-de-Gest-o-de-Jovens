<?php
require_once __DIR__.'/paths.php';
if(session_status()!==PHP_SESSION_ACTIVE){session_name('SIGJSESSID');session_set_cookie_params(['httponly'=>true,'secure'=>!empty($_SERVER['HTTPS']),'samesite'=>'Lax','path'=>'/']);session_start();}
$entities=require __DIR__.'/entities.php';require_once __DIR__.'/../data/JsonRepository.php';$repo=new JsonRepository($entities);
function currentUser():?array{return $_SESSION['user']??null;}function requireAuth():void{global $repo;$sessionUser=currentUser();if(!$sessionUser){$_SESSION['flash']=['type'=>'error','text'=>'Inicie sessão para continuar.'];header('Location: /auth/login.php');exit;}$fresh=$repo->find('utilizadores',(string)($sessionUser['id']??''));if(!$fresh||($fresh['active']??'Activo')!=='Activo'){$_SESSION=[];session_destroy();header('Location: /auth/login.php');exit;}unset($fresh['password']);$_SESSION['user']=$fresh;}
function csrfToken():string{if(empty($_SESSION['csrf']))$_SESSION['csrf']=bin2hex(random_bytes(32));return $_SESSION['csrf'];}function verifyCsrf():void{if(!hash_equals(csrfToken(),(string)($_POST['_csrf']??''))){http_response_code(419);exit('Pedido expirado. Actualize a página e tente novamente.');}}
function flash(string $type,string $text):void{$_SESSION['flash']=['type'=>$type,'text'=>$text];}function takeFlash():?array{$f=$_SESSION['flash']??null;unset($_SESSION['flash']);return $f;}
function rolePermissions(string $role): array {
    $all=['view','create','edit'];
    $admin=['view','create','edit'];
    return match($role){
        'Administrador'=>array_fill_keys(array_keys(require __DIR__.'/entities.php'),$admin)+['dashboard'=>$admin,'relatorios'=>$admin,'configuracoes'=>$admin],
        'Gestor'=>array_fill_keys(['clientes','processos','candidatos','vagas','prazos','relatorios'], $all)+['dashboard'=>['view'],'configuracoes'=>['view','edit']],
        'Funcionário'=>['clientes'=>['view','create','edit'],'processos'=>['view','create','edit'],'prazos'=>['view','create','edit'],'dashboard'=>['view'],'configuracoes'=>['view','edit']],
        'Supervisor'=>['dashboard'=>['view'],'estagiarios'=>['view','create','edit'],'configuracoes'=>['view','edit']],
        default=>[]
    };
}
function can(string $module,string $action='view'):bool{
    $u=currentUser();if(!$u)return false;$role=$u['perfil']??'';
    if($action==='delete')return false;
    if($role==='Administrador')return true;
    if(in_array($module,['utilizadores'],true))return false;
    if($module==='supervisores'&&$action!=='view')return false;
    if($module==='estagiarios'&&$role!=='Supervisor'&&!isset($u['permissions'][$module]))return false;
    $permissions=$u['permissions']??null;
    if(is_array($permissions)&&array_key_exists($module,$permissions))return in_array($action,(array)$permissions[$module],true);
    return in_array($action,rolePermissions($role)[$module]??[],true);
}
function requirePermission(string $module,string $action='view'):void{requireAuth();if(!can($module,$action)){http_response_code(403);$pageTitle='Acesso recusado';echo '<!doctype html><meta charset="utf-8"><title>Acesso recusado</title><h1>Acesso recusado</h1><p>O seu perfil não tem permissão para esta operação.</p><a href="/index.php">Voltar ao painel</a>';exit;}}
function redirect(string $to):never{header('Location: '.$to);exit;}function postValue(string $key):string|array{return $_POST[$key]??'';}
function valueLabel(array $entity,string $key):string{return $entity['fields'][$key][0]??$key;}

function csrfInput():void{echo '<input type="hidden" name="_csrf" value="'.e(csrfToken()).'">';}
function iconSvg(string $name,string $class='ui-icon'):string{return '<svg class="'.e($class).'" aria-hidden="true" focusable="false"><use href="/assets/icons/ui.svg#'.e($name).'"></use></svg>';}
function recordIsActive(array $record):bool{$value=$record['active']??$record['ativo']??true;return !($value===false||$value===0||$value==='0'||$value==='Inactivo'||$value==='Inativo');}
function scopedRows(string $module,JsonRepository $repo,bool $includeInactive=false):array{
    $user=currentUser();if(!$user)return [];$rows=$repo->all($module);
    if(($user['perfil']??'')!=='Administrador'){
        if($module==='supervisores')$rows=array_values(array_filter($rows,fn($r)=>($r['id']??'')===($user['supervisor_id']??'')));
        else {$owners=[$user['id']??''];if(($user['perfil']??'')==='Gestor'&&in_array($module,['clientes','processos','prazos'],true)){foreach($repo->all('utilizadores') as $account)if(($account['perfil']??'')==='Funcionário')$owners[]=$account['id'];}$rows=array_values(array_filter($rows,fn($r)=>in_array(($r['_owner_id']??''),$owners,true)));}
    }
    if(!$includeInactive)$rows=array_values(array_filter($rows,'recordIsActive'));
    return $rows;
}
function canAccessRecord(string $module,array $record,JsonRepository $repo,string $action='view'):bool{
    $owner=$record['_owner_id']??'';$user=currentUser();
    if($action!=='view'&&($user['perfil']??'')==='Gestor'&&in_array($module,['clientes','processos','prazos'],true)){foreach($repo->all('utilizadores') as $account)if(($account['id']??'')===$owner&&($account['perfil']??'')==='Funcionário')return false;}
    foreach(scopedRows($module,$repo,true) as $row)if(($row['id']??null)===($record['id']??null))return true;
    return false;
}
function deadlineIsLocked(array $record):bool{return !empty($record['data_limite'])&&$record['data_limite']<(new DateTimeImmutable('today'))->format('Y-m-d');}
function deadlineStatus(array $record):string{
    $deadline=(string)($record['data_limite']??'');$delivered=(string)($record['data_entrega']??'');
    if($delivered!=='')return $delivered<=$deadline?'Entregue no prazo':'Entregue fora do prazo';
    if($deadline==='')return 'Dentro do prazo';
    $today=(new DateTimeImmutable('today'))->format('Y-m-d');if($deadline<$today)return 'Vencido';if($deadline<=(new DateTimeImmutable('today'))->modify('+3 days')->format('Y-m-d'))return 'Próximo';return 'Dentro do prazo';
}




