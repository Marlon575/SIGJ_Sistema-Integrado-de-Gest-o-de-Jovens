<?php
$entities = [
'clientes'=>['title'=>'Clientes','singular'=>'Cliente','prefix'=>'CL','fields'=>['nome'=>['Nome','text',true],'email'=>['E-mail','email',true],'telefone'=>['Telefone','text',true],'endereco'=>['Endereço','textarea',false]]],
'processos'=>['title'=>'Processos','singular'=>'Processo','prefix'=>'PR','fields'=>['cliente_id'=>['Cliente associado','relation:clientes',true],'numero'=>['Número do processo','text',true],'tipo'=>['Tipo de processo','text',true],'descricao'=>['Descrição','textarea',false],'estado'=>['Estado','options:Pendente|Em andamento|Concluído|Cancelado',true],'data_abertura'=>['Data de abertura','date',true]]],
'supervisores'=>['title'=>'Supervisores','singular'=>'Supervisor','prefix'=>'SV','fields'=>['nome'=>['Nome','text',true],'email'=>['E-mail','email',true],'telefone'=>['Telefone','text',true],'especialidade'=>['Especialidade','text',true]]],
'estagiarios'=>['title'=>'Estagiários','singular'=>'Estagiário','prefix'=>'ES','fields'=>['supervisor_id'=>['Supervisor associado','relation:supervisores',true],'nome'=>['Nome','text',true],'email'=>['E-mail','email',true],'telefone'=>['Telefone','text',true],'instituicao'=>['Instituição de ensino','text',true],'estado'=>['Situação do estágio','options:Em andamento|Concluído contratado|Concluído não contratado',true]]],
'candidatos'=>['title'=>'Candidatos','singular'=>'Candidato','prefix'=>'CA','fields'=>['nome'=>['Nome','text',true],'email'=>['E-mail','email',true],'telefone'=>['Telefone','text',true],'formacao'=>['Formação','text',true],'vaga_ids'=>['Vagas associadas','relation-many:vagas',false]]],
'vagas'=>['title'=>'Vagas','singular'=>'Vaga','prefix'=>'VG','fields'=>['titulo'=>['Título','text',true],'descricao'=>['Descrição','textarea',true],'requisitos'=>['Requisitos','textarea',false],'data_abertura'=>['Data de abertura','date',true],'estado'=>['Estado','options:Aberta|Encerrada|Suspensa',true]]],
'prazos'=>['title'=>'Prazos','singular'=>'Prazo','prefix'=>'PZ','fields'=>['processo_id'=>['Processo associado','relation:processos',true],'descricao'=>['Descrição','text',true],'data_limite'=>['Data limite','date',true],'estado'=>['Estado','options:Dentro do prazo|Próximo|Vencido|Entregue no prazo|Entregue fora do prazo',true],'data_entrega'=>['Data de entrega','date',false],'nota_atraso'=>['Motivo do atraso','textarea',false]]],
'utilizadores'=>['title'=>'Utilizadores','singular'=>'Utilizador','prefix'=>'UT','fields'=>['nome'=>['Nome','text',true],'email'=>['E-mail','email',true],'password'=>['Palavra-passe','password',false],'perfil'=>['Perfil','options:Administrador|Gestor|Funcionário|Supervisor',true],'supervisor_id'=>['Supervisor associado','relation:supervisores',false],'active'=>['Estado','options:Activo|Inactivo',true]]],
];
foreach (['clientes','processos','supervisores','estagiarios','candidatos','vagas','prazos'] as $module) {
    $entities[$module]['fields']['ativo'] = ['Situação do registo','options:Activo|Inactivo',true];
}
return $entities;
