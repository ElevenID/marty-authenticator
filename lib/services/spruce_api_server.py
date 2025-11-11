"""
Flask REST API for SpruceID Backend Integration
This provides HTTP endpoints for server-side SSI operations.
"""

import asyncio
import logging

from flask import Flask, jsonify, request
from spruce_backend_service import spruce_backend

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint."""
    return jsonify(
        {
            "status": "healthy",
            "service": "SpruceID Backend API",
            "spruceid_available": spruce_backend.didkit is not None,
        }
    )


@app.route("/did/create", methods=["POST"])
def create_did():
    """Create a new DID."""
    try:
        data = request.get_json() or {}
        method = data.get("method", "key")
        options = data.get("options", {})

        # Run async function in sync context
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(spruce_backend.create_did(method, options))
        loop.close()

        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e), "status": "failed"}), 500


@app.route("/credential/sign", methods=["POST"])
def sign_credential():
    """Sign a verifiable credential."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400

        credential = data.get("credential")
        key_jwk = data.get("keyJwk")
        verification_method = data.get("verificationMethod")

        if not all([credential, key_jwk, verification_method]):
            return jsonify(
                {
                    "error": "Missing required fields: credential, keyJwk, verificationMethod"
                }
            ), 400

        # Convert key_jwk to string if it's a dict
        if isinstance(key_jwk, dict):
            import json

            key_jwk = json.dumps(key_jwk)

        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(
            spruce_backend.sign_credential(credential, key_jwk, verification_method)
        )
        loop.close()

        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e), "status": "failed"}), 500


@app.route("/credential/verify", methods=["POST"])
def verify_credential():
    """Verify a verifiable credential."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No credential provided"}), 400

        credential = data.get("credential")
        if not credential:
            return jsonify({"error": "No credential provided"}), 400

        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(spruce_backend.verify_credential(credential))
        loop.close()

        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e), "status": "failed"}), 500


@app.route("/mdoc/create", methods=["POST"])
def create_mdoc():
    """Create an mDoc."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400

        doc_type = data.get("docType", "org.iso.18013.5.1.mDL")
        issuer_signed_items = data.get("issuerSignedItems", {})
        issuer_auth = data.get("issuerAuth", {})

        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        mdoc_bytes = loop.run_until_complete(
            spruce_backend.create_mdoc(doc_type, issuer_signed_items, issuer_auth)
        )
        loop.close()

        # Convert bytes to base64 for JSON response
        import base64

        mdoc_b64 = base64.b64encode(mdoc_bytes).decode("utf-8")

        return jsonify({"mdoc": mdoc_b64, "docType": doc_type, "status": "success"})

    except Exception as e:
        return jsonify({"error": str(e), "status": "failed"}), 500


@app.route("/age/verify", methods=["POST"])
def verify_age():
    """Verify age from mDoc."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400

        mdoc_b64 = data.get("mdoc")
        minimum_age = data.get("minimumAge", 18)

        if not mdoc_b64:
            return jsonify({"error": "No mDoc provided"}), 400

        # Convert base64 back to bytes
        import base64

        mdoc_bytes = base64.b64decode(mdoc_b64)

        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(
            spruce_backend.verify_age_from_mdoc(mdoc_bytes, minimum_age)
        )
        loop.close()

        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e), "status": "failed"}), 500


@app.route("/sd-jwt/create", methods=["POST"])
def create_sd_jwt():
    """Create an SD-JWT."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400

        claims = data.get("claims", {})
        disclosable_claims = data.get("disclosableClaims", [])
        issuer_key = data.get("issuerKey")

        if not issuer_key:
            return jsonify({"error": "No issuer key provided"}), 400

        # Convert key to string if it's a dict
        if isinstance(issuer_key, dict):
            import json

            issuer_key = json.dumps(issuer_key)

        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        sd_jwt = loop.run_until_complete(
            spruce_backend.create_sd_jwt(claims, disclosable_claims, issuer_key)
        )
        loop.close()

        return jsonify(
            {
                "sdJwt": sd_jwt,
                "claims": claims,
                "disclosableClaims": disclosable_claims,
                "status": "success",
            }
        )

    except Exception as e:
        return jsonify({"error": str(e), "status": "failed"}), 500


@app.route("/sd-jwt/verify", methods=["POST"])
def verify_sd_jwt():
    """Verify an SD-JWT."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400

        sd_jwt = data.get("sdJwt")
        issuer_public_key = data.get("issuerPublicKey")

        if not all([sd_jwt, issuer_public_key]):
            return jsonify(
                {"error": "Missing required fields: sdJwt, issuerPublicKey"}
            ), 400

        # Convert key to string if it's a dict
        if isinstance(issuer_public_key, dict):
            import json

            issuer_public_key = json.dumps(issuer_public_key)

        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(
            spruce_backend.verify_sd_jwt(sd_jwt, issuer_public_key)
        )
        loop.close()

        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e), "status": "failed"}), 500


if __name__ == "__main__":
    print("Starting SpruceID Backend API...")
    print("Endpoints:")
    print("  GET  /health - Health check")
    print("  POST /did/create - Create DID")
    print("  POST /credential/sign - Sign credential")
    print("  POST /credential/verify - Verify credential")
    print("  POST /mdoc/create - Create mDoc")
    print("  POST /age/verify - Verify age from mDoc")
    print("  POST /sd-jwt/create - Create SD-JWT")
    print("  POST /sd-jwt/verify - Verify SD-JWT")

    app.run(debug=True, host="0.0.0.0", port=5000)
