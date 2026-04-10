#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
// EXTRA BEGIN
typedef struct DartCObject *WireSyncRust2DartDco;
typedef struct WireSyncRust2DartSse {
  uint8_t *ptr;
  int32_t len;
} WireSyncRust2DartSse;

typedef int64_t DartPort;
typedef bool (*DartPostCObjectFnType)(DartPort port_id, void *message);
void store_dart_post_cobject(DartPostCObjectFnType ptr);
// EXTRA END
typedef struct _Dart_Handle* Dart_Handle;

typedef struct wire_cst_list_prim_u_8_strict {
  uint8_t *ptr;
  int32_t len;
} wire_cst_list_prim_u_8_strict;

typedef struct wire_cst_list_String {
  struct wire_cst_list_prim_u_8_strict **ptr;
  int32_t len;
} wire_cst_list_String;

typedef struct wire_cst_credential_subject {
  struct wire_cst_list_prim_u_8_strict *id;
  struct wire_cst_list_prim_u_8_strict *claims_json;
} wire_cst_credential_subject;

typedef struct wire_cst_proof {
  struct wire_cst_list_prim_u_8_strict *proof_type;
  struct wire_cst_list_prim_u_8_strict *created;
  struct wire_cst_list_prim_u_8_strict *verification_method;
  struct wire_cst_list_prim_u_8_strict *proof_purpose;
  struct wire_cst_list_prim_u_8_strict *proof_value;
} wire_cst_proof;

typedef struct wire_cst_credential_status {
  struct wire_cst_list_prim_u_8_strict *status_type;
  struct wire_cst_list_prim_u_8_strict *status_list_credential;
  struct wire_cst_list_prim_u_8_strict *status_list_index;
} wire_cst_credential_status;

typedef struct wire_cst_verifiable_credential {
  struct wire_cst_list_prim_u_8_strict *id;
  struct wire_cst_list_String *types;
  struct wire_cst_list_prim_u_8_strict *issuer;
  struct wire_cst_list_prim_u_8_strict *issuer_name;
  struct wire_cst_list_prim_u_8_strict *issuance_date;
  struct wire_cst_list_prim_u_8_strict *expiration_date;
  struct wire_cst_credential_subject subject;
  struct wire_cst_proof *proof;
  struct wire_cst_credential_status *status;
  struct wire_cst_list_prim_u_8_strict *raw_json;
} wire_cst_verifiable_credential;

typedef struct wire_cst_Credential_VerifiableCredential {
  struct wire_cst_verifiable_credential *field0;
} wire_cst_Credential_VerifiableCredential;

typedef struct wire_cst_trust_info {
  bool is_valid;
  struct wire_cst_list_prim_u_8_strict *trust_anchor;
  struct wire_cst_list_prim_u_8_strict *status_message;
  struct wire_cst_list_String *certificate_chain;
} wire_cst_trust_info;

typedef struct wire_cst_m_doc_credential {
  struct wire_cst_list_prim_u_8_strict *id;
  struct wire_cst_list_prim_u_8_strict *doc_type;
  struct wire_cst_list_prim_u_8_strict *issuing_authority;
  struct wire_cst_list_prim_u_8_strict *issuing_country;
  struct wire_cst_list_prim_u_8_strict *expiry_date;
  struct wire_cst_list_prim_u_8_strict *namespaces_json;
  struct wire_cst_trust_info *trust_info;
  struct wire_cst_list_prim_u_8_strict *portrait;
  struct wire_cst_list_prim_u_8_strict *signature;
} wire_cst_m_doc_credential;

typedef struct wire_cst_Credential_MDoc {
  struct wire_cst_m_doc_credential *field0;
} wire_cst_Credential_MDoc;

typedef struct wire_cst_sd_jwt_credential {
  struct wire_cst_list_prim_u_8_strict *id;
  struct wire_cst_list_String *types;
  struct wire_cst_list_prim_u_8_strict *issuer;
  struct wire_cst_list_prim_u_8_strict *issuance_date;
  struct wire_cst_list_prim_u_8_strict *expiration_date;
  struct wire_cst_list_prim_u_8_strict *disclosed_claims_json;
  struct wire_cst_list_String *disclosable_claims;
  struct wire_cst_list_prim_u_8_strict *key_binding;
} wire_cst_sd_jwt_credential;

typedef struct wire_cst_Credential_SdJwt {
  struct wire_cst_sd_jwt_credential *field0;
} wire_cst_Credential_SdJwt;

typedef union CredentialKind {
  struct wire_cst_Credential_VerifiableCredential VerifiableCredential;
  struct wire_cst_Credential_MDoc MDoc;
  struct wire_cst_Credential_SdJwt SdJwt;
} CredentialKind;

typedef struct wire_cst_credential {
  int32_t tag;
  union CredentialKind kind;
} wire_cst_credential;

typedef struct wire_cst_list_credential {
  struct wire_cst_credential *ptr;
  int32_t len;
} wire_cst_list_credential;

typedef struct wire_cst_list_prim_u_8_loose {
  uint8_t *ptr;
  int32_t len;
} wire_cst_list_prim_u_8_loose;

typedef struct wire_cst_rankable_credential_input {
  struct wire_cst_list_prim_u_8_strict *credential_id;
  struct wire_cst_list_prim_u_8_strict *issuer_id;
  int64_t issued_at_unix;
  double trust_level;
  uintptr_t claim_count;
} wire_cst_rankable_credential_input;

typedef struct wire_cst_list_rankable_credential_input {
  struct wire_cst_rankable_credential_input *ptr;
  int32_t len;
} wire_cst_list_rankable_credential_input;

typedef struct wire_cst_list_list_prim_u_8_strict {
  struct wire_cst_list_prim_u_8_strict **ptr;
  int32_t len;
} wire_cst_list_list_prim_u_8_strict;

typedef struct wire_cst_frb_zk_proof_entry {
  struct wire_cst_list_prim_u_8_strict *descriptor_id;
  struct wire_cst_list_prim_u_8_strict *predicate_id;
  struct wire_cst_list_prim_u_8_strict *proof_bytes;
} wire_cst_frb_zk_proof_entry;

typedef struct wire_cst_list_frb_zk_proof_entry {
  struct wire_cst_frb_zk_proof_entry *ptr;
  int32_t len;
} wire_cst_list_frb_zk_proof_entry;

typedef struct wire_cst_list_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerPresentationPolicy {
  uintptr_t *ptr;
  int32_t len;
} wire_cst_list_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerPresentationPolicy;

typedef struct wire_cst_credential_group {
  struct wire_cst_list_prim_u_8_strict *issuer;
  struct wire_cst_list_prim_u_8_strict *issuer_name;
  struct wire_cst_list_credential *credentials;
  struct wire_cst_list_prim_u_8_strict *logo_url;
} wire_cst_credential_group;

typedef struct wire_cst_list_credential_group {
  struct wire_cst_credential_group *ptr;
  int32_t len;
} wire_cst_list_credential_group;

typedef struct wire_cst_frb_age_estimate {
  uint8_t estimated_age;
  float confidence;
  uint8_t age_range_low;
  uint8_t age_range_high;
} wire_cst_frb_age_estimate;

typedef struct wire_cst_frb_authorization_request {
  struct wire_cst_list_prim_u_8_strict *authorization_url;
  struct wire_cst_list_prim_u_8_strict *code_verifier;
  struct wire_cst_list_prim_u_8_strict *state;
  struct wire_cst_list_prim_u_8_strict *redirect_uri;
} wire_cst_frb_authorization_request;

typedef struct wire_cst_frb_credential_offer {
  struct wire_cst_list_prim_u_8_strict *credential_issuer;
  struct wire_cst_list_String *credential_configuration_ids;
  struct wire_cst_list_prim_u_8_strict *pre_authorized_code;
  bool tx_code_required;
  struct wire_cst_list_prim_u_8_strict *issuer_state;
} wire_cst_frb_credential_offer;

typedef struct wire_cst_frb_credential_response {
  struct wire_cst_list_prim_u_8_strict *format;
  struct wire_cst_list_prim_u_8_strict *credential;
  struct wire_cst_list_prim_u_8_strict *transaction_id;
  struct wire_cst_list_prim_u_8_strict *c_nonce;
  uint64_t *c_nonce_expires_in;
} wire_cst_frb_credential_response;

typedef struct wire_cst_frb_face_match_result {
  bool verified;
  float similarity;
  float threshold;
  struct wire_cst_list_prim_u_8_strict *provider;
  float *reference_quality;
  float *probe_quality;
  uint64_t processing_time_ms;
} wire_cst_frb_face_match_result;

typedef struct wire_cst_frb_face_quality {
  float overall_score;
  bool face_detected;
  uint32_t face_count;
  float sharpness;
  float brightness;
  float contrast;
  float face_size;
  float pose;
} wire_cst_frb_face_quality;

typedef struct wire_cst_frb_issuer_metadata {
  struct wire_cst_list_prim_u_8_strict *credential_issuer;
  struct wire_cst_list_prim_u_8_strict *token_endpoint;
  struct wire_cst_list_prim_u_8_strict *credential_endpoint;
  struct wire_cst_list_prim_u_8_strict *authorization_endpoint;
  struct wire_cst_list_String *grant_types_supported;
  struct wire_cst_list_prim_u_8_strict *credential_configurations_json;
} wire_cst_frb_issuer_metadata;

typedef struct wire_cst_frb_presentation_request {
  struct wire_cst_list_prim_u_8_strict *client_id;
  struct wire_cst_list_prim_u_8_strict *nonce;
  struct wire_cst_list_prim_u_8_strict *response_uri;
  struct wire_cst_list_prim_u_8_strict *presentation_definition_json;
} wire_cst_frb_presentation_request;

typedef struct wire_cst_frb_presentation_response {
  bool ok;
  struct wire_cst_list_prim_u_8_strict *redirect_uri;
  struct wire_cst_list_prim_u_8_strict *error;
  struct wire_cst_list_prim_u_8_strict *error_description;
} wire_cst_frb_presentation_response;

typedef struct wire_cst_frb_token_response {
  struct wire_cst_list_prim_u_8_strict *access_token;
  struct wire_cst_list_prim_u_8_strict *token_type;
  uint64_t *expires_in;
  struct wire_cst_list_prim_u_8_strict *c_nonce;
  uint64_t *c_nonce_expires_in;
  struct wire_cst_list_prim_u_8_strict *scope;
} wire_cst_frb_token_response;

typedef struct wire_cst_issuer_check_result_output {
  bool is_trusted;
  struct wire_cst_list_prim_u_8_strict *violation_message;
} wire_cst_issuer_check_result_output;

typedef struct wire_cst_policy_evaluation_result {
  bool is_satisfied;
  struct wire_cst_list_String *minimum_disclosure_claims;
  struct wire_cst_list_String *missing_required_claims;
  struct wire_cst_list_prim_u_8_strict *policy_id;
} wire_cst_policy_evaluation_result;

typedef struct wire_cst_selectable_credential {
  struct wire_cst_credential credential;
  bool is_selected;
  struct wire_cst_list_String *selected_claims;
  int32_t privacy_level;
} wire_cst_selectable_credential;

void frbgen_privacyidea_authenticator_wire__crate__biometrics__assess_face_quality(int64_t port_,
                                                                                   struct wire_cst_list_prim_u_8_strict *image,
                                                                                   struct wire_cst_list_prim_u_8_strict *models_dir);

void frbgen_privacyidea_authenticator_wire__crate__api__check_issuer_constraints(int64_t port_,
                                                                                 struct wire_cst_list_prim_u_8_strict *policy_json,
                                                                                 struct wire_cst_list_prim_u_8_strict *issuer_id,
                                                                                 bool trust_profile_verified);

void frbgen_privacyidea_authenticator_wire__crate__api__create_selectable_credential(int64_t port_,
                                                                                     struct wire_cst_credential *credential,
                                                                                     int32_t privacy_level);

void frbgen_privacyidea_authenticator_wire__crate__api__credential_from_json(int64_t port_,
                                                                             struct wire_cst_list_prim_u_8_strict *json);

void frbgen_privacyidea_authenticator_wire__crate__api__credential_to_json(int64_t port_,
                                                                           struct wire_cst_credential *credential);

void frbgen_privacyidea_authenticator_wire__crate__biometrics__estimate_face_age(int64_t port_,
                                                                                 struct wire_cst_list_prim_u_8_strict *image,
                                                                                 struct wire_cst_list_prim_u_8_strict *models_dir);

void frbgen_privacyidea_authenticator_wire__crate__api__evaluate_presentation_request(int64_t port_,
                                                                                      struct wire_cst_list_prim_u_8_strict *request_json,
                                                                                      struct wire_cst_list_String *policies_json,
                                                                                      struct wire_cst_list_credential *credentials);

void frbgen_privacyidea_authenticator_wire__crate__api__get_credential_claims(int64_t port_,
                                                                              struct wire_cst_credential *credential);

void frbgen_privacyidea_authenticator_wire__crate__api__get_minimum_disclosure_set(int64_t port_,
                                                                                   struct wire_cst_list_prim_u_8_strict *policy_json,
                                                                                   struct wire_cst_credential *credential);

void frbgen_privacyidea_authenticator_wire__crate__api__group_credentials_by_issuer(int64_t port_,
                                                                                    struct wire_cst_list_credential *credentials);

void frbgen_privacyidea_authenticator_wire__crate__api__is_credential_expired(int64_t port_,
                                                                              struct wire_cst_credential *credential);

void frbgen_privacyidea_authenticator_wire__crate__api__parse_mdoc_credential(int64_t port_,
                                                                              struct wire_cst_list_prim_u_8_loose *cbor_bytes);

void frbgen_privacyidea_authenticator_wire__crate__api__parse_sd_jwt_credential(int64_t port_,
                                                                                struct wire_cst_list_prim_u_8_strict *sd_jwt);

void frbgen_privacyidea_authenticator_wire__crate__api__parse_verifiable_credential(int64_t port_,
                                                                                    struct wire_cst_list_prim_u_8_strict *json);

void frbgen_privacyidea_authenticator_wire__crate__api__rank_matching_credentials(int64_t port_,
                                                                                  struct wire_cst_list_prim_u_8_strict *policy_json,
                                                                                  struct wire_cst_list_rankable_credential_input *credentials);

void frbgen_privacyidea_authenticator_wire__crate__api__sync_policies(int64_t port_,
                                                                      struct wire_cst_list_prim_u_8_strict *license_jwt,
                                                                      struct wire_cst_list_prim_u_8_strict *endpoint);

void frbgen_privacyidea_authenticator_wire__crate__api__verify_and_attach_trust(int64_t port_,
                                                                                struct wire_cst_m_doc_credential *mdoc,
                                                                                struct wire_cst_list_list_prim_u_8_strict *x5chain);

void frbgen_privacyidea_authenticator_wire__crate__biometrics__verify_face_match(int64_t port_,
                                                                                 struct wire_cst_list_prim_u_8_strict *reference_image,
                                                                                 struct wire_cst_list_prim_u_8_strict *probe_image,
                                                                                 float *threshold,
                                                                                 struct wire_cst_list_prim_u_8_strict *models_dir);

void frbgen_privacyidea_authenticator_wire__crate__api__verify_mdoc_trust_chain(int64_t port_,
                                                                                struct wire_cst_list_list_prim_u_8_strict *x5chain);

void frbgen_privacyidea_authenticator_wire__crate__api__wallet_build_and_submit_presentation(int64_t port_,
                                                                                             struct wire_cst_list_prim_u_8_strict *response_uri,
                                                                                             struct wire_cst_list_prim_u_8_strict *presentation_definition_json,
                                                                                             struct wire_cst_list_prim_u_8_strict *credentials_json);

void frbgen_privacyidea_authenticator_wire__crate__api__wallet_build_and_submit_zk_presentation(int64_t port_,
                                                                                                struct wire_cst_list_prim_u_8_strict *response_uri,
                                                                                                struct wire_cst_list_prim_u_8_strict *presentation_definition_json,
                                                                                                struct wire_cst_list_prim_u_8_strict *credentials_json,
                                                                                                struct wire_cst_list_frb_zk_proof_entry *zk_proofs);

void frbgen_privacyidea_authenticator_wire__crate__api__wallet_build_auth_request(int64_t port_,
                                                                                  struct wire_cst_list_prim_u_8_strict *issuer_metadata_json,
                                                                                  struct wire_cst_list_prim_u_8_strict *credential_configuration_id,
                                                                                  struct wire_cst_list_prim_u_8_strict *client_id,
                                                                                  struct wire_cst_list_prim_u_8_strict *redirect_uri,
                                                                                  struct wire_cst_list_prim_u_8_strict *issuer_state);

void frbgen_privacyidea_authenticator_wire__crate__api__wallet_create_proof_jwt(int64_t port_,
                                                                                struct wire_cst_list_prim_u_8_strict *holder_kid,
                                                                                struct wire_cst_list_prim_u_8_strict *c_nonce,
                                                                                struct wire_cst_list_prim_u_8_strict *issuer_url,
                                                                                struct wire_cst_list_prim_u_8_strict *jwk_json);

void frbgen_privacyidea_authenticator_wire__crate__api__wallet_exchange_auth_code_token(int64_t port_,
                                                                                        struct wire_cst_list_prim_u_8_strict *token_endpoint,
                                                                                        struct wire_cst_list_prim_u_8_strict *code,
                                                                                        struct wire_cst_list_prim_u_8_strict *code_verifier,
                                                                                        struct wire_cst_list_prim_u_8_strict *redirect_uri,
                                                                                        struct wire_cst_list_prim_u_8_strict *client_id);

void frbgen_privacyidea_authenticator_wire__crate__api__wallet_exchange_pre_auth_token(int64_t port_,
                                                                                       struct wire_cst_list_prim_u_8_strict *token_endpoint,
                                                                                       struct wire_cst_list_prim_u_8_strict *pre_auth_code,
                                                                                       struct wire_cst_list_prim_u_8_strict *tx_code);

void frbgen_privacyidea_authenticator_wire__crate__api__wallet_fetch_issuer_metadata(int64_t port_,
                                                                                     struct wire_cst_list_prim_u_8_strict *issuer_url);

void frbgen_privacyidea_authenticator_wire__crate__api__wallet_parse_credential_offer(int64_t port_,
                                                                                      struct wire_cst_list_prim_u_8_strict *offer_uri);

void frbgen_privacyidea_authenticator_wire__crate__api__wallet_parse_presentation_request(int64_t port_,
                                                                                          struct wire_cst_list_prim_u_8_strict *request_uri);

void frbgen_privacyidea_authenticator_wire__crate__api__wallet_request_credential(int64_t port_,
                                                                                  struct wire_cst_list_prim_u_8_strict *credential_endpoint,
                                                                                  struct wire_cst_list_prim_u_8_strict *access_token,
                                                                                  struct wire_cst_list_prim_u_8_strict *credential_format,
                                                                                  struct wire_cst_list_prim_u_8_strict *credential_configuration_id,
                                                                                  struct wire_cst_list_prim_u_8_strict *proof_jwt);

void frbgen_privacyidea_authenticator_wire__crate__api__zk_is_supported_on_device(int64_t port_);

void frbgen_privacyidea_authenticator_wire__crate__api__zk_prove(int64_t port_,
                                                                 struct wire_cst_list_prim_u_8_strict *predicate_id,
                                                                 struct wire_cst_list_prim_u_8_strict *claim_value,
                                                                 struct wire_cst_list_prim_u_8_loose *mdoc_bytes,
                                                                 struct wire_cst_list_prim_u_8_strict *issuer_pkx,
                                                                 struct wire_cst_list_prim_u_8_strict *issuer_pky,
                                                                 struct wire_cst_list_prim_u_8_strict *doc_type,
                                                                 struct wire_cst_list_prim_u_8_loose *session_nonce);

void frbgen_privacyidea_authenticator_wire__crate__api__zk_prove_from_presentation_definition(int64_t port_,
                                                                                              struct wire_cst_list_prim_u_8_strict *presentation_definition_json,
                                                                                              struct wire_cst_list_prim_u_8_loose *mdoc_bytes,
                                                                                              struct wire_cst_list_prim_u_8_strict *issuer_pkx,
                                                                                              struct wire_cst_list_prim_u_8_strict *issuer_pky,
                                                                                              struct wire_cst_list_prim_u_8_strict *doc_type,
                                                                                              struct wire_cst_list_prim_u_8_strict *secrets_json,
                                                                                              struct wire_cst_list_prim_u_8_loose *session_nonce);

void frbgen_privacyidea_authenticator_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerPresentationPolicy(const void *ptr);

void frbgen_privacyidea_authenticator_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerPresentationPolicy(const void *ptr);

struct wire_cst_credential *frbgen_privacyidea_authenticator_cst_new_box_autoadd_credential(void);

struct wire_cst_credential_status *frbgen_privacyidea_authenticator_cst_new_box_autoadd_credential_status(void);

float *frbgen_privacyidea_authenticator_cst_new_box_autoadd_f_32(float value);

struct wire_cst_m_doc_credential *frbgen_privacyidea_authenticator_cst_new_box_autoadd_m_doc_credential(void);

struct wire_cst_proof *frbgen_privacyidea_authenticator_cst_new_box_autoadd_proof(void);

struct wire_cst_sd_jwt_credential *frbgen_privacyidea_authenticator_cst_new_box_autoadd_sd_jwt_credential(void);

struct wire_cst_trust_info *frbgen_privacyidea_authenticator_cst_new_box_autoadd_trust_info(void);

uint64_t *frbgen_privacyidea_authenticator_cst_new_box_autoadd_u_64(uint64_t value);

struct wire_cst_verifiable_credential *frbgen_privacyidea_authenticator_cst_new_box_autoadd_verifiable_credential(void);

struct wire_cst_list_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerPresentationPolicy *frbgen_privacyidea_authenticator_cst_new_list_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerPresentationPolicy(int32_t len);

struct wire_cst_list_String *frbgen_privacyidea_authenticator_cst_new_list_String(int32_t len);

struct wire_cst_list_credential *frbgen_privacyidea_authenticator_cst_new_list_credential(int32_t len);

struct wire_cst_list_credential_group *frbgen_privacyidea_authenticator_cst_new_list_credential_group(int32_t len);

struct wire_cst_list_frb_zk_proof_entry *frbgen_privacyidea_authenticator_cst_new_list_frb_zk_proof_entry(int32_t len);

struct wire_cst_list_list_prim_u_8_strict *frbgen_privacyidea_authenticator_cst_new_list_list_prim_u_8_strict(int32_t len);

struct wire_cst_list_prim_u_8_loose *frbgen_privacyidea_authenticator_cst_new_list_prim_u_8_loose(int32_t len);

struct wire_cst_list_prim_u_8_strict *frbgen_privacyidea_authenticator_cst_new_list_prim_u_8_strict(int32_t len);

struct wire_cst_list_rankable_credential_input *frbgen_privacyidea_authenticator_cst_new_list_rankable_credential_input(int32_t len);
static int64_t dummy_method_to_enforce_bundling(void) {
    int64_t dummy_var = 0;
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_credential_status);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_f_32);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_m_doc_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_proof);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_sd_jwt_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_trust_info);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_u_64);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_verifiable_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerPresentationPolicy);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_String);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_credential_group);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_frb_zk_proof_entry);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_list_prim_u_8_strict);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_prim_u_8_loose);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_prim_u_8_strict);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_rankable_credential_input);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerPresentationPolicy);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerPresentationPolicy);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__check_issuer_constraints);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__create_selectable_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__credential_from_json);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__credential_to_json);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__evaluate_presentation_request);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__get_credential_claims);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__get_minimum_disclosure_set);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__group_credentials_by_issuer);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__is_credential_expired);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__parse_mdoc_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__parse_sd_jwt_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__parse_verifiable_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__rank_matching_credentials);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__sync_policies);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__verify_and_attach_trust);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__verify_mdoc_trust_chain);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__wallet_build_and_submit_presentation);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__wallet_build_and_submit_zk_presentation);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__wallet_build_auth_request);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__wallet_create_proof_jwt);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__wallet_exchange_auth_code_token);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__wallet_exchange_pre_auth_token);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__wallet_fetch_issuer_metadata);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__wallet_parse_credential_offer);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__wallet_parse_presentation_request);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__wallet_request_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__zk_is_supported_on_device);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__zk_prove);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__zk_prove_from_presentation_definition);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__biometrics__assess_face_quality);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__biometrics__estimate_face_age);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__biometrics__verify_face_match);
    dummy_var ^= ((int64_t) (void*) store_dart_post_cobject);
    return dummy_var;
}
