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

typedef struct wire_cst_list_list_prim_u_8_strict {
  struct wire_cst_list_prim_u_8_strict **ptr;
  int32_t len;
} wire_cst_list_list_prim_u_8_strict;

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

typedef struct wire_cst_selectable_credential {
  struct wire_cst_credential credential;
  bool is_selected;
  struct wire_cst_list_String *selected_claims;
  int32_t privacy_level;
} wire_cst_selectable_credential;

void frbgen_privacyidea_authenticator_wire__crate__api__create_selectable_credential(int64_t port_,
                                                                                     struct wire_cst_credential *credential,
                                                                                     int32_t privacy_level);

void frbgen_privacyidea_authenticator_wire__crate__api__credential_from_json(int64_t port_,
                                                                             struct wire_cst_list_prim_u_8_strict *json);

void frbgen_privacyidea_authenticator_wire__crate__api__credential_to_json(int64_t port_,
                                                                           struct wire_cst_credential *credential);

void frbgen_privacyidea_authenticator_wire__crate__api__get_credential_claims(int64_t port_,
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

void frbgen_privacyidea_authenticator_wire__crate__api__verify_and_attach_trust(int64_t port_,
                                                                                struct wire_cst_m_doc_credential *mdoc,
                                                                                struct wire_cst_list_list_prim_u_8_strict *x5chain);

void frbgen_privacyidea_authenticator_wire__crate__api__verify_mdoc_trust_chain(int64_t port_,
                                                                                struct wire_cst_list_list_prim_u_8_strict *x5chain);

struct wire_cst_credential *frbgen_privacyidea_authenticator_cst_new_box_autoadd_credential(void);

struct wire_cst_credential_status *frbgen_privacyidea_authenticator_cst_new_box_autoadd_credential_status(void);

struct wire_cst_m_doc_credential *frbgen_privacyidea_authenticator_cst_new_box_autoadd_m_doc_credential(void);

struct wire_cst_proof *frbgen_privacyidea_authenticator_cst_new_box_autoadd_proof(void);

struct wire_cst_sd_jwt_credential *frbgen_privacyidea_authenticator_cst_new_box_autoadd_sd_jwt_credential(void);

struct wire_cst_trust_info *frbgen_privacyidea_authenticator_cst_new_box_autoadd_trust_info(void);

struct wire_cst_verifiable_credential *frbgen_privacyidea_authenticator_cst_new_box_autoadd_verifiable_credential(void);

struct wire_cst_list_String *frbgen_privacyidea_authenticator_cst_new_list_String(int32_t len);

struct wire_cst_list_credential *frbgen_privacyidea_authenticator_cst_new_list_credential(int32_t len);

struct wire_cst_list_credential_group *frbgen_privacyidea_authenticator_cst_new_list_credential_group(int32_t len);

struct wire_cst_list_list_prim_u_8_strict *frbgen_privacyidea_authenticator_cst_new_list_list_prim_u_8_strict(int32_t len);

struct wire_cst_list_prim_u_8_loose *frbgen_privacyidea_authenticator_cst_new_list_prim_u_8_loose(int32_t len);

struct wire_cst_list_prim_u_8_strict *frbgen_privacyidea_authenticator_cst_new_list_prim_u_8_strict(int32_t len);
static int64_t dummy_method_to_enforce_bundling(void) {
    int64_t dummy_var = 0;
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_credential_status);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_m_doc_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_proof);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_sd_jwt_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_trust_info);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_box_autoadd_verifiable_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_String);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_credential_group);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_list_prim_u_8_strict);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_prim_u_8_loose);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_cst_new_list_prim_u_8_strict);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__create_selectable_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__credential_from_json);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__credential_to_json);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__get_credential_claims);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__group_credentials_by_issuer);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__is_credential_expired);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__parse_mdoc_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__parse_sd_jwt_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__parse_verifiable_credential);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__verify_and_attach_trust);
    dummy_var ^= ((int64_t) (void*) frbgen_privacyidea_authenticator_wire__crate__api__verify_mdoc_trust_chain);
    dummy_var ^= ((int64_t) (void*) store_dart_post_cobject);
    return dummy_var;
}
