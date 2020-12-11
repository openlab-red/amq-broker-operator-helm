{{/*
Expand the name of the chart.
*/}}
{{- define "amq-broker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "amq-broker.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "amq-broker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "amq-broker.labels" -}}
helm.sh/chart: {{ include "amq-broker.chart" . }}
{{ include "amq-broker.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "amq-broker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "amq-broker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "amq-broker.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "amq-broker.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Generate certificates for amq broker
Dns pod <broker-name>-ss-<replica>
Service Headless <broker-name>-hdls-svc
Service <broker-name>-<acceptor-name>-<replica>-svc
Route  <broker-name>-<acceptor-name>-<replica>-svc-rte
svc.cluster.local
*/}}
{{- define "amq-broker.gen-certs" -}}
{{- $cn:= printf "%s-*-svc-rte-%s.%s" (include "amq-broker.fullname" .) .Release.Namespace .Values.clusterDomain -}}
{{- $altNames := list $cn ( printf "%s-*-svc.%s.svc" (include "amq-broker.fullname" .) .Release.Namespace ) -}}
{{- $ca := genCA "amq-broker-ca" 365 -}}
{{- $cert := genSignedCert $cn  nil $altNames 365 $ca -}}
tls.crt: {{ $cert.Cert | b64enc }}
tls.key: {{ $cert.Key | b64enc }}
ca.crt: {{ $ca.Cert | b64enc }}
{{- end -}}


{{/*
Generate acceptors broker.xml
*/}}
{{- define "amq-broker.acceptors" -}}
{{- $fullName := ( include "amq-broker.fullname" . ) -}}
{{ range .Values.acceptors }}
{{- $acceptor := . -}}
{{- with $ }}
<acceptor name="{{ $acceptor.name }}">tcp://${BROKER_IP}:{{ $acceptor.port }}?protocols=
{{- if eq $acceptor.protocols "all" -}}
AMQP,CORE,HORNETQ,MQTT,OPENWIRE,STOMP
{{- else -}}
{{- upper $acceptor.protocols -}}
{{- end -}}
{{- if $acceptor.sslEnabled -}}
;sslEnabled=true;keyStorePath=/etc/{{ $fullName }}-all-secret-volume/broker.ks;keyStorePassword={{ .Values.pki.keyStorePassword }};trustStorePath=/etc/{{ $fullName }}-all-secret-volume/client.ts;trustStorePassword={{ .Values.pki.trustStorePassword }};
{{- else -}}
;
{{- end -}}
tcpSendBufferSize=1048576;tcpReceiveBufferSize=1048576;useEpoll=true;amqpCredits=1000;amqpMinCredits=300</acceptor>
{{- end -}}
{{- end }}
{{- end }}

{{/*
Generate connectors broker.xml
TODO: Read the connector ssl secret automatically
*/}}
{{- define "amq-broker.connectors" -}}
{{- $fullName := ( include "amq-broker.fullname" . ) -}}
{{ range .Values.connectors }}
{{- $connector := . -}}
{{- with $ }}
<connector name="{{ $connector.name }}">{{ $connector.type }}://{{ $connector.host }}:{{ $connector.port }}
{{- if $connector.sslEnabled -}}
;sslEnabled=true;keyStorePath=/etc/{{ $connector.sslSecret }}-volume/broker.ks;keyStorePassword={{ .Values.pki.keyStorePassword }};trustStorePath=/etc/{{ $connector.sslSecret }}-volume/client.ts;trustStorePassword={{ .Values.pki.trustStorePassword }}
{{- else -}}
;
{{- end -}}
</connector>
{{- end -}}
{{- end }}
{{- end }}


