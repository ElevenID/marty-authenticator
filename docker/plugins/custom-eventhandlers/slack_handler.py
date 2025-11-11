"""
Custom Event Handler Example: Slack Notification Handler
This event handler sends notifications to Slack when certain events occur.
"""

import logging

import requests
from privacyidea.lib.eventhandler.base import BaseEventHandler

log = logging.getLogger(__name__)


class SlackNotificationEventHandler(BaseEventHandler):
    """
    Event handler that sends notifications to Slack channels.

    Example use cases:
    - Notify when user fails authentication multiple times
    - Alert when new tokens are enrolled
    - Send daily/weekly usage reports
    """

    identifier = "SlackNotification"
    description = "Send notifications to Slack channels"

    def __init__(self):
        super(SlackNotificationEventHandler, self).__init__()

    @property
    def allowed_positions(self):
        """This handler can run in post-event position"""
        return ["post", "pre"]

    @property
    def actions(self):
        """Available actions for this handler"""
        return ["send_message", "send_alert"]

    def check_condition(self, options=None):
        """
        Check if the event should trigger this handler.
        You can check user attributes, request details, etc.
        """
        request = options.get("request")
        handler_def = options.get("handler_def", {})

        # Example: Only trigger for certain realms
        conditions = handler_def.get("condition", {})
        if "realm" in conditions:
            required_realm = conditions["realm"]
            # Check if current request matches required realm
            # Implementation depends on your logic

        return True

    def do(self, action, options=None):
        """
        Execute the handler action.
        """
        try:
            if action == "send_message":
                return self._send_slack_message(options)
            elif action == "send_alert":
                return self._send_slack_alert(options)
            else:
                log.error(f"Unknown action: {action}")
                return False
        except Exception as e:
            log.error(f"Slack handler error: {e}")
            return False

    def _send_slack_message(self, options):
        """Send a regular message to Slack"""
        handler_def = options.get("handler_def", {})
        webhook_url = handler_def.get("options", {}).get("webhook_url")

        if not webhook_url:
            log.error("No Slack webhook URL configured")
            return False

        # Get event context
        g = options.get("g")
        request = options.get("request")
        response = options.get("response")

        # Build message based on context
        message = self._build_message(handler_def, g, request, response)

        payload = {"text": message, "username": "privacyIDEA", "icon_emoji": ":shield:"}

        response = requests.post(webhook_url, json=payload, timeout=10)
        return response.status_code == 200

    def _send_slack_alert(self, options):
        """Send an alert (high priority) to Slack"""
        handler_def = options.get("handler_def", {})
        webhook_url = handler_def.get("options", {}).get("webhook_url")

        if not webhook_url:
            log.error("No Slack webhook URL configured")
            return False

        # Build alert message
        g = options.get("g")
        request = options.get("request")

        message = f"🚨 *SECURITY ALERT* 🚨\n{self._build_message(handler_def, g, request, None)}"

        payload = {
            "text": message,
            "username": "privacyIDEA Security",
            "icon_emoji": ":warning:",
            "attachments": [
                {
                    "color": "danger",
                    "fields": [
                        {
                            "title": "Event Time",
                            "value": f"{g.audit_object.audit_data.get('date', 'Unknown')}",
                            "short": True,
                        },
                        {
                            "title": "Source IP",
                            "value": f"{request.remote_addr if request else 'Unknown'}",
                            "short": True,
                        },
                    ],
                }
            ],
        }

        response = requests.post(webhook_url, json=payload, timeout=10)
        return response.status_code == 200

    def _build_message(self, handler_def, g, request, response):
        """Build the notification message based on context"""
        template = handler_def.get("options", {}).get(
            "message_template", "Event: {action} - User: {user} - Result: {success}"
        )

        # Extract audit data
        audit_data = g.audit_object.audit_data if g and g.audit_object else {}

        return template.format(
            action=audit_data.get("action", "Unknown"),
            user=audit_data.get("user", "Unknown"),
            success=audit_data.get("success", "Unknown"),
            realm=audit_data.get("realm", "Unknown"),
            client=audit_data.get("client", "Unknown"),
        )


# Register the event handler
def get_handler_class():
    """Return the handler class for dynamic loading"""
    return SlackNotificationEventHandler
