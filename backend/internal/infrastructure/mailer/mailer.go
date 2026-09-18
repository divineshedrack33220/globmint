// Package mailer delivers transactional email. In production it sends through
// the Resend API (api.resend.com) using a verified sending domain so delivery
// lands in the inbox instead of spam (SPF/DKIM are managed in the Resend
// dashboard). In local dev without an API key it falls back to logging the
// message so the OTP flow is still exercisable end to end.
package mailer

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"strings"
	"time"
)

//go:embed assets/logo.png
var logoPNG []byte

const logoCID = "globmint-logo"

var tmplFuncs = template.FuncMap{
	"logo": func() template.URL { return template.URL("cid:" + logoCID) },
}

// Sender delivers transactional email: one-time codes, money-movement
// notifications, and security alerts.
type Sender interface {
	SendOTP(ctx context.Context, to, code string) error
	// SendMoneyReceived emails the user that funds arrived in their account.
	// amount is a pre-formatted display string (e.g. "₦1,234.56").
	SendMoneyReceived(ctx context.Context, to, name, amount string) error
	// SendMoneySent emails the user a confirmation that funds left their
	// account.
	SendMoneySent(ctx context.Context, to, name, amount string) error
	// SendNewSignIn alerts the user to a first-time (previously unseen)
	// device signing in. Only the owning user sees device name/IP.
	SendNewSignIn(ctx context.Context, to, deviceName, ip, timestamp string) error
	// SendFailedSignIn alerts the user that repeated login attempts failed.
	// Only the owning user sees the IP/timestamp.
	SendFailedSignIn(ctx context.Context, to, ip, timestamp string) error
}

// New returns a Resend-backed Sender when an API key is configured, otherwise a
// console sender that logs the code (dev fallback; never used in production).
func New(apiKey, from string) Sender {
	if err := validateFrom(from); err != nil {
		log.Printf("mailer: using console fallback: %v", err)
		return &consoleSender{}
	}
	if apiKey == "" {
		log.Println("mailer: no GLOBMINT_RESEND_API_KEY set; logging OTP codes to stdout (dev only)")
		return &consoleSender{}
	}
	return &resendClient{apiKey: apiKey, from: from, http: &http.Client{Timeout: 15 * time.Second}}
}

func validateFrom(from string) error {
	if from == "" {
		return fmt.Errorf("send-from address is empty")
	}
	// Resend requires a real verified domain; "Name <addr>" is the accepted
	// format. A bare address is tolerated so dev projects only must set the
	// domain. This is deliberately light — Resend validates at send time.
	return nil
}

// consoleSender prints the message to the process log so local development can
// read it without an outbound email service.
type consoleSender struct{}

func (c *consoleSender) SendOTP(_ context.Context, to, code string) error {
	log.Printf("mailer [dev fallback]: OTP for %s -> %s (expires in 10m)", code, to)
	return nil
}

func (c *consoleSender) SendMoneyReceived(_ context.Context, to, name, amount string) error {
	log.Printf("mailer [dev fallback]: money received %s -> %s (%s)", amount, to, name)
	return nil
}

func (c *consoleSender) SendMoneySent(_ context.Context, to, name, amount string) error {
	log.Printf("mailer [dev fallback]: money sent %s -> %s (%s)", amount, to, name)
	return nil
}

func (c *consoleSender) SendNewSignIn(_ context.Context, to, deviceName, ip, timestamp string) error {
	log.Printf("mailer [dev fallback]: new sign-in for %s from %s (%s) at %s", to, deviceName, ip, timestamp)
	return nil
}

func (c *consoleSender) SendFailedSignIn(_ context.Context, to, ip, timestamp string) error {
	log.Printf("mailer [dev fallback]: failed sign-in attempts for %s from %s at %s", to, ip, timestamp)
	return nil
}

const resendBaseURL = "https://api.resend.com/emails"

// resendClient sends through the Resend HTTP API using a bearer API key.
type resendClient struct {
	apiKey string
	from   string
	http   *http.Client
}

type resendAttachment struct {
	Filename    string `json:"filename"`
	Content     string `json:"content,omitempty"`
	ContentType string `json:"content_type,omitempty"`
	ContentID   string `json:"content_id,omitempty"`
}

type resendSendRequest struct {
	From        string             `json:"from"`
	To          []string           `json:"to"`
	Subject     string             `json:"subject"`
	HTML        string             `json:"html"`
	Attachments []resendAttachment `json:"attachments,omitempty"`
}

func (r *resendClient) SendOTP(ctx context.Context, to, code string) error {
	return r.sendEmail(ctx, to, "Your Globmint verification code", otpBody(code))
}

func (r *resendClient) SendMoneyReceived(ctx context.Context, to, name, amount string) error {
	return r.sendEmail(ctx, to, "You received "+amount+" in your Globmint account", moneyBody(moneyNotification{
		Greeting: greeting(name),
		Amount:   amount,
		Label:    "Money received",
		Note:     "Someone sent you money and your Globmint balance has been topped up.",
	}))
}

func (r *resendClient) SendMoneySent(ctx context.Context, to, name, amount string) error {
	return r.sendEmail(ctx, to, "You sent "+amount+" from your Globmint account", moneyBody(moneyNotification{
		Greeting: greeting(name),
		Amount:   amount,
		Label:    "Money sent",
		Note:     "This is a confirmation that money left your Globmint account.",
	}))
}

func (r *resendClient) SendNewSignIn(ctx context.Context, to, deviceName, ip, timestamp string) error {
	return r.sendEmail(ctx, to, "New sign-in to your Globmint account", securityAlertBody(securityAlert{
		Heading: "A new device signed in to your account",
		Rows: []securityRow{
			{Label: "Device", Value: deviceName},
			{Label: "IP address", Value: ip},
			{Label: "Time", Value: timestamp},
		},
		Note: "If this wasn't you, please secure your account immediately and contact support.",
	}))
}

func (r *resendClient) SendFailedSignIn(ctx context.Context, to, ip, timestamp string) error {
	return r.sendEmail(ctx, to, "Failed sign-in attempts on your Globmint account", securityAlertBody(securityAlert{
		Heading: "There were repeated failed sign-in attempts on your account",
		Rows: []securityRow{
			{Label: "IP address", Value: ip},
			{Label: "Time", Value: timestamp},
		},
		Note: "If this wasn't you, please secure your account immediately and contact support.",
	}))
}

func (r *resendClient) sendEmail(ctx context.Context, to, subject, html string) error {
	body := resendSendRequest{
		From:    r.from,
		To:      []string{to},
		Subject: subject,
		HTML:    html,
		Attachments: []resendAttachment{{
			Filename:    logoCID + ".png",
			Content:     base64.StdEncoding.EncodeToString(logoPNG),
			ContentType: "image/png",
			ContentID:   logoCID,
		}},
	}
	payload, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("mailer: encode: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, resendBaseURL, bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("mailer: request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	resp, err := r.http.Do(req)
	if err != nil {
		return fmt.Errorf("mailer: send to %s: %w", to, err)
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode >= 300 {
		var er struct {
			Message string `json:"message"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&er)
		reason := er.Message
		if reason == "" {
			reason = resp.Status
		}
		return fmt.Errorf("mailer: resend api status %d: %s", resp.StatusCode, reason)
	}
	return nil
}

var otpTmpl = template.Must(template.New("otp").Funcs(tmplFuncs).Parse(`<!doctype html>
<html>
  <body style="margin:0;padding:0;background:#0a0a0a;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif">
    <div style="max-width:480px;margin:40px auto;background:#111;border:1px solid #2a2a2a;border-radius:16px;padding:32px;color:#f5f5f5">
      <div style="display:flex;align-items:center;gap:12px;margin:0 0 8px">
        <img src="{{logo}}" width="40" height="40" alt="Globmint logo" style="width:40px;height:40px;border-radius:10px;display:block">
        <div style="font-weight:700;font-size:17px;letter-spacing:-0.3px;color:#f5f5f5">Globmint</div>
      </div>
      <p style="margin:0 0 20px;color:#a0a0a0;font-size:14px">Your one-time verification code</p>
      <div style="background:#0a0a0a;border:1px solid #2a2a2a;border-radius:12px;text-align:center;padding:18px 0;font-size:34px;letter-spacing:14px;font-weight:700;color:#d6fb57">{{.}}</div>
      <p style="margin:18px 0 0;color:#a0a0a0;font-size:13px;line-height:1.5">
        This code expires in 10 minutes. If you did not request it, you can safely ignore this email.
      </p>
    </div>
  </body>
</html>`))

func otpBody(code string) string {
	var buf bytes.Buffer
	_ = otpTmpl.Execute(&buf, code)
	return buf.String()
}

type moneyNotification struct {
	Greeting string
	Amount   string
	Label    string
	Note     string
}

var moneyTmpl = template.Must(template.New("money").Funcs(tmplFuncs).Parse(`<!doctype html>
<html>
  <body style="margin:0;padding:0;background:#0a0a0a;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif">
    <div style="max-width:480px;margin:40px auto;background:#111;border:1px solid #2a2a2a;border-radius:16px;padding:32px;color:#f5f5f5">
      <div style="display:flex;align-items:center;gap:12px;margin:0 0 24px">
        <img src="{{logo}}" width="40" height="40" alt="Globmint logo" style="width:40px;height:40px;border-radius:10px;display:block">
        <div style="font-weight:700;font-size:15px;letter-spacing:-0.3px;color:#f5f5f5">Globmint</div>
      </div>
      <p style="margin:0 0 8px;font-size:16px;font-weight:600;color:#f5f5f5">{{.Greeting}}</p>
      <p style="margin:0 0 24px;color:#a0a0a0;font-size:14px">{{.Note}}</p>
      <div style="background:#0a0a0a;border:1px solid #2a2a2a;border-radius:12px;text-align:center;padding:18px 0">
        <p style="margin:0 0 6px;font-size:12px;text-transform:uppercase;letter-spacing:1px;color:#a0a0a0">{{.Label}}</p>
        <p style="margin:0;font-size:30px;font-weight:700;color:#d6fb57">{{.Amount}}</p>
      </div>
      <p style="margin:24px 0 0;color:#a0a0a0;font-size:13px;line-height:1.5">If you did not expect this transaction, please secure your account and contact support.</p>
    </div>
  </body>
</html>`))

func moneyBody(n moneyNotification) string {
	var buf bytes.Buffer
	_ = moneyTmpl.Execute(&buf, n)
	return buf.String()
}

func greeting(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		name = "Globmint user"
	}
	return "Hey, " + name
}

type securityRow struct {
	Label string
	Value string
}

type securityAlert struct {
	Heading string
	Rows    []securityRow
	Note    string
}

var securityAlertTmpl = template.Must(template.New("security").Funcs(tmplFuncs).Parse(`<!doctype html>
<html>
  <body style="margin:0;padding:0;background:#0a0a0a;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif">
    <div style="max-width:480px;margin:40px auto;background:#111;border:1px solid #2a2a2a;border-radius:16px;padding:32px;color:#f5f5f5">
      <div style="display:flex;align-items:center;gap:12px;margin:0 0 8px">
        <img src="{{logo}}" width="40" height="40" alt="Globmint logo" style="width:40px;height:40px;border-radius:10px;display:block">
        <div style="font-weight:700;font-size:17px;letter-spacing:-0.3px;color:#f5f5f5">Globmint</div>
      </div>
      <p style="margin:0 0 20px;color:#a0a0a0;font-size:14px">{{.Heading}}</p>
      <div style="background:#0a0a0a;border:1px solid #2a2a2a;border-radius:12px;padding:16px;margin:0 0 16px">
        {{range .Rows}}
        <p style="margin:0 0 4px;font-size:13px;color:#a0a0a0;text-transform:uppercase;letter-spacing:0.5px">{{.Label}}</p>
        <p style="margin:0 0 12px;font-size:15px;color:#f5f5f5">{{.Value}}</p>
        {{end}}
      </div>
      <p style="margin:0;color:#a0a0a0;font-size:13px;line-height:1.5">{{.Note}}</p>
    </div>
  </body>
</html>`))

func securityAlertBody(a securityAlert) string {
	var buf bytes.Buffer
	_ = securityAlertTmpl.Execute(&buf, a)
	return buf.String()
}
