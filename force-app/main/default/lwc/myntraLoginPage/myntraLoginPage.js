import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import login from "@salesforce/apex/MyntraLoginController.login";

const TOAST_DURATION = 3200;

export default class MyntraLoginPage extends LightningElement {
  @api forgotPasswordUrl = "/ForgotPassword";
  @api selfRegisterUrl = "/Register";
  @api startUrl;

  username = "";
  password = "";
  isPasswordVisible = false;
  isSubmitting = false;
  errorMessage = "";
  toastMessage = "";

  _queryStartUrl = "";
  _toastTimer;

  @wire(CurrentPageReference)
  getPageRef(pageRef) {
    const startURLParam = pageRef?.state?.startURL;
    if (startURLParam) {
      this._queryStartUrl = decodeURIComponent(startURLParam);
    }
  }

  disconnectedCallback() {
    window.clearTimeout(this._toastTimer);
  }

  get hasError() {
    return Boolean(this.errorMessage);
  }

  get passwordInputType() {
    return this.isPasswordVisible ? "text" : "password";
  }

  get passwordToggleLabel() {
    return this.isPasswordVisible ? "Hide" : "Show";
  }

  get submitLabel() {
    return this.isSubmitting ? "Signing In…" : "Sign In →";
  }

  get toastClassName() {
    return `toast${this.toastMessage ? " is-visible" : ""}`;
  }

  handleUsernameChange(event) {
    this.username = event.target.value;
  }

  handlePasswordChange(event) {
    this.password = event.target.value;
  }

  togglePasswordVisibility() {
    this.isPasswordVisible = !this.isPasswordVisible;
  }

  handleSubmit(event) {
    event.preventDefault();
    if (this.isSubmitting) {
      return;
    }

    this.errorMessage = "";
    this.isSubmitting = true;

    const resolvedStartUrl = this.startUrl || this._queryStartUrl || "/";

    login({ username: this.username, password: this.password, startUrl: resolvedStartUrl })
      .then((redirectUrl) => {
        window.location.href = redirectUrl;
      })
      .catch((error) => {
        this.isSubmitting = false;
        this.errorMessage = this.reduceError(error);
        this.showToast(this.errorMessage);
      });
  }

  reduceError(error) {
    if (Array.isArray(error?.body)) {
      return error.body.map((item) => item.message).join(", ");
    }
    return (
      error?.body?.message ||
      error?.message ||
      "We couldn't sign you in. Please check your username and password."
    );
  }

  showToast(message) {
    window.clearTimeout(this._toastTimer);
    this.toastMessage = message;
    this._toastTimer = window.setTimeout(() => {
      this.toastMessage = "";
    }, TOAST_DURATION);
  }
}