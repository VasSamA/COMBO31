---
title: COMBO PRO 3 em 1 - Laboratórios
permalink: index.html
layout: home
---

# COMBO PRO 3 em 1 - Windows Server + Microsoft 365 + Azure

**VASSAMA Academy | "Do Datacenter à Cloud"**

Comece pelo [Guia do Aluno auto-guiado](Instructions/Guias/00_Comecar_Aqui.html) e pelo [LAB00](Instructions/Labs/LAB_00_Preparar_o_Ambiente.html).

## Guias

{% assign guias = site.pages | where_exp:"page", "page.url contains '/Instructions/Guias'" | sort: "url" %}
| Guia |
| --- |
{% for g in guias %}| [{{ g.title }}]({{ site.github.url }}{{ g.url }}) |
{% endfor %}

## Laboratórios

{% assign labs = site.pages | where_exp:"page", "page.url contains '/Instructions/Labs'" | sort: "url" %}
| Domingo | Lab |
| --- | --- |
{% for activity in labs %}| {{ activity.lab.module }} | [{{ activity.lab.title }}]({{ site.github.url }}{{ activity.url }}) |
{% endfor %}
