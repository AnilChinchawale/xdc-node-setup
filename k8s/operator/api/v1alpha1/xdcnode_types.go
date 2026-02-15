/*
Copyright 2024 XDC Network.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1alpha1

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE! THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required. Any new fields you add must have json tags for the fields to be serialized.

// XDCNodeSpec defines the desired state of XDCNode
type XDCNodeSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Network is the XDC network to connect to (mainnet, testnet, devnet)
	// +kubebuilder:validation:Enum=mainnet;testnet;devnet
	// +kubebuilder:default=mainnet
	Network string `json:"network"`

	// Client is the XDC client implementation (XDPoSChain, erigon-xdc)
	// +kubebuilder:validation:Enum=XDPoSChain;erigon-xdc
	// +kubebuilder:default=XDPoSChain
	// +optional
	Client string `json:"client,omitempty"`

	// NodeType is the type of node to run (full, archive, validator, rpc)
	// +kubebuilder:validation:Enum=full;archive;validator;rpc
	// +kubebuilder:default=full
	// +optional
	NodeType string `json:"nodeType,omitempty"`

	// Image contains the container image configuration
	// +optional
	Image ImageSpec `json:"image,omitempty"`

	// Replicas is the number of replicas (only for RPC nodes)
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=10
	// +kubebuilder:default=1
	// +optional
	Replicas int32 `json:"replicas,omitempty"`

	// RPC contains the RPC endpoint configuration
	// +optional
	RPC RPCSpec `json:"rpc,omitempty"`

	// WebSocket contains the WebSocket endpoint configuration
	// +optional
	WebSocket WebSocketSpec `json:"websocket,omitempty"`

	// P2P contains the P2P networking configuration
	// +optional
	P2P P2PSpec `json:"p2p,omitempty"`

	// Metrics contains the Prometheus metrics configuration
	// +optional
	Metrics MetricsSpec `json:"metrics,omitempty"`

	// Storage contains the persistent storage configuration
	// +optional
	Storage StorageSpec `json:"storage,omitempty"`

	// Resources contains resource requirements
	// +optional
	Resources corev1.ResourceRequirements `json:"resources,omitempty"`

	// Validator contains validator-specific configuration
	// +optional
	Validator ValidatorSpec `json:"validator,omitempty"`

	// Sync contains sync configuration
	// +optional
	Sync SyncSpec `json:"sync,omitempty"`

	// ExtraFlags contains additional command line flags
	// +optional
	ExtraFlags []string `json:"extraFlags,omitempty"`

	// Service contains service configuration
	// +optional
	Service ServiceSpec `json:"service,omitempty"`

	// Ingress contains ingress configuration
	// +optional
	Ingress IngressSpec `json:"ingress,omitempty"`

	// NodeSelector for pod scheduling
	// +optional
	NodeSelector map[string]string `json:"nodeSelector,omitempty"`

	// Tolerations for pod scheduling
	// +optional
	Tolerations []corev1.Toleration `json:"tolerations,omitempty"`

	// Affinity for pod scheduling
	// +optional
	Affinity *corev1.Affinity `json:"affinity,omitempty"`
}

// ImageSpec defines container image configuration
type ImageSpec struct {
	// Repository is the image repository
	// +kubebuilder:default="xinfin/xdc-node"
	Repository string `json:"repository,omitempty"`

	// Tag is the image tag
	// +kubebuilder:default="latest"
	Tag string `json:"tag,omitempty"`

	// PullPolicy is the image pull policy
	// +kubebuilder:validation:Enum=Always;IfNotPresent;Never
	// +kubebuilder:default=IfNotPresent
	PullPolicy corev1.PullPolicy `json:"pullPolicy,omitempty"`
}

// RPCSpec defines RPC endpoint configuration
type RPCSpec struct {
	// Enabled enables the HTTP RPC endpoint
	// +kubebuilder:default=true
	Enabled bool `json:"enabled,omitempty"`

	// Port is the RPC port
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=65535
	// +kubebuilder:default=8545
	Port int32 `json:"port,omitempty"`

	// API is the list of enabled RPC APIs
	// +kubebuilder:default={"eth","net","web3","txpool"}
	API []string `json:"api,omitempty"`

	// CorsDomain is the CORS domain
	// +kubebuilder:default="*"
	CorsDomain string `json:"corsDomain,omitempty"`

	// VHosts is the virtual hosts setting
	// +kubebuilder:default="*"
	VHosts string `json:"vhosts,omitempty"`
}

// WebSocketSpec defines WebSocket endpoint configuration
type WebSocketSpec struct {
	// Enabled enables the WebSocket endpoint
	// +kubebuilder:default=false
	Enabled bool `json:"enabled,omitempty"`

	// Port is the WebSocket port
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=65535
	// +kubebuilder:default=8546
	Port int32 `json:"port,omitempty"`

	// API is the list of enabled WebSocket APIs
	// +kubebuilder:default={"eth","net","web3"}
	API []string `json:"api,omitempty"`
}

// P2PSpec defines P2P networking configuration
type P2PSpec struct {
	// Port is the P2P port
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=65535
	// +kubebuilder:default=30303
	Port int32 `json:"port,omitempty"`

	// MaxPeers is the maximum number of peers
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=200
	// +kubebuilder:default=50
	MaxPeers int32 `json:"maxPeers,omitempty"`

	// Bootnodes is a list of custom bootnode URLs
	// +optional
	Bootnodes []string `json:"bootnodes,omitempty"`
}

// MetricsSpec defines Prometheus metrics configuration
type MetricsSpec struct {
	// Enabled enables the metrics endpoint
	// +kubebuilder:default=true
	Enabled bool `json:"enabled,omitempty"`

	// Port is the metrics port
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=65535
	// +kubebuilder:default=6060
	Port int32 `json:"port,omitempty"`
}

// StorageSpec defines persistent storage configuration
type StorageSpec struct {
	// Enabled enables persistent storage
	// +kubebuilder:default=true
	Enabled bool `json:"enabled,omitempty"`

	// Size is the volume size
	// +kubebuilder:default="500Gi"
	Size string `json:"size,omitempty"`

	// StorageClass is the storage class name
	// +optional
	StorageClass string `json:"storageClass,omitempty"`

	// AccessMode is the volume access mode
	// +kubebuilder:validation:Enum=ReadWriteOnce;ReadWriteMany
	// +kubebuilder:default=ReadWriteOnce
	AccessMode corev1.PersistentVolumeAccessMode `json:"accessMode,omitempty"`
}

// ValidatorSpec defines validator-specific configuration
type ValidatorSpec struct {
	// Enabled enables validator mode
	// +kubebuilder:default=false
	Enabled bool `json:"enabled,omitempty"`

	// Address is the validator wallet address
	// +optional
	Address string `json:"address,omitempty"`

	// KeystoreSecret is the name of the secret containing the keystore
	// +optional
	KeystoreSecret string `json:"keystoreSecret,omitempty"`

	// PasswordSecret is the name of the secret containing the password
	// +optional
	PasswordSecret string `json:"passwordSecret,omitempty"`
}

// SyncSpec defines sync configuration
type SyncSpec struct {
	// Mode is the sync mode
	// +kubebuilder:validation:Enum=snap;full;archive
	// +kubebuilder:default=snap
	Mode string `json:"mode,omitempty"`

	// GCMode is the garbage collection mode
	// +kubebuilder:validation:Enum=full;archive
	// +kubebuilder:default=full
	GCMode string `json:"gcMode,omitempty"`

	// CacheSize is the cache size in MB
	// +kubebuilder:validation:Minimum=256
	// +kubebuilder:validation:Maximum=65536
	// +kubebuilder:default=4096
	CacheSize int32 `json:"cacheSize,omitempty"`
}

// ServiceSpec defines service configuration
type ServiceSpec struct {
	// Type is the service type
	// +kubebuilder:validation:Enum=ClusterIP;NodePort;LoadBalancer
	// +kubebuilder:default=ClusterIP
	Type corev1.ServiceType `json:"type,omitempty"`

	// Annotations for the service
	// +optional
	Annotations map[string]string `json:"annotations,omitempty"`
}

// IngressSpec defines ingress configuration
type IngressSpec struct {
	// Enabled enables ingress
	// +kubebuilder:default=false
	Enabled bool `json:"enabled,omitempty"`

	// ClassName is the ingress class
	// +kubebuilder:default="nginx"
	ClassName string `json:"className,omitempty"`

	// Host is the ingress hostname
	// +optional
	Host string `json:"host,omitempty"`

	// Annotations for the ingress
	// +optional
	Annotations map[string]string `json:"annotations,omitempty"`

	// TLS enables TLS
	// +kubebuilder:default=true
	TLS bool `json:"tls,omitempty"`

	// TLSSecretName is the name of the TLS secret
	// +optional
	TLSSecretName string `json:"tlsSecretName,omitempty"`
}

// XDCNodeStatus defines the observed state of XDCNode
type XDCNodeStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Phase is the current phase of the node
	// +optional
	Phase string `json:"phase,omitempty"`

	// Conditions are the conditions for the XDCNode
	// +optional
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// SyncStatus contains the blockchain sync status
	// +optional
	SyncStatus SyncStatus `json:"syncStatus,omitempty"`

	// NetworkInfo contains network information
	// +optional
	NetworkInfo NetworkInfo `json:"networkInfo,omitempty"`

	// Endpoints contains available endpoints
	// +optional
	Endpoints Endpoints `json:"endpoints,omitempty"`

	// ObservedGeneration is the generation observed by the controller
	// +optional
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`

	// LastUpdated is the timestamp of the last status update
	// +optional
	LastUpdated *metav1.Time `json:"lastUpdated,omitempty"`
}

// SyncStatus defines the sync status
type SyncStatus struct {
	// Syncing indicates if the node is currently syncing
	Syncing bool `json:"syncing,omitempty"`

	// CurrentBlock is the current block number
	CurrentBlock int64 `json:"currentBlock,omitempty"`

	// HighestBlock is the highest known block number
	HighestBlock int64 `json:"highestBlock,omitempty"`

	// StartingBlock is the block number where sync started
	StartingBlock int64 `json:"startingBlock,omitempty"`

	// SyncProgress is the sync progress percentage
	SyncProgress string `json:"syncProgress,omitempty"`
}

// NetworkInfo defines network information
type NetworkInfo struct {
	// ChainID is the chain ID
	ChainID int64 `json:"chainId,omitempty"`

	// NetworkID is the network ID
	NetworkID int64 `json:"networkId,omitempty"`

	// PeerCount is the number of connected peers
	PeerCount int32 `json:"peerCount,omitempty"`

	// Enode is the enode URL
	Enode string `json:"enode,omitempty"`
}

// Endpoints defines available endpoints
type Endpoints struct {
	// RPC is the HTTP RPC endpoint
	RPC string `json:"rpc,omitempty"`

	// WebSocket is the WebSocket endpoint
	WebSocket string `json:"websocket,omitempty"`

	// P2P is the P2P endpoint
	P2P string `json:"p2p,omitempty"`

	// Metrics is the metrics endpoint
	Metrics string `json:"metrics,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Network",type="string",JSONPath=".spec.network"
// +kubebuilder:printcolumn:name="Client",type="string",JSONPath=".spec.client"
// +kubebuilder:printcolumn:name="Type",type="string",JSONPath=".spec.nodeType"
// +kubebuilder:printcolumn:name="Phase",type="string",JSONPath=".status.phase"
// +kubebuilder:printcolumn:name="Block",type="integer",JSONPath=".status.syncStatus.currentBlock"
// +kubebuilder:printcolumn:name="Peers",type="integer",JSONPath=".status.networkInfo.peerCount"
// +kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"

// XDCNode is the Schema for the xdcnodes API
type XDCNode struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   XDCNodeSpec   `json:"spec,omitempty"`
	Status XDCNodeStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// XDCNodeList contains a list of XDCNode
type XDCNodeList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []XDCNode `json:"items"`
}

func init() {
	SchemeBuilder.Register(&XDCNode{}, &XDCNodeList{})
}

// NodePhase constants
const (
	NodePhasePending     = "Pending"
	NodePhaseCreating    = "Creating"
	NodePhaseSyncing     = "Syncing"
	NodePhaseReady       = "Ready"
	NodePhaseError       = "Error"
	NodePhaseTerminating = "Terminating"
)

// Condition types
const (
	ConditionTypeReady       = "Ready"
	ConditionTypeSynced      = "Synced"
	ConditionTypeProgressing = "Progressing"
	ConditionTypeDegraded    = "Degraded"
)
