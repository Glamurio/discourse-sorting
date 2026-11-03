import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { ajax } from "discourse/lib/ajax";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const HIDDEN_KEY = "discourse-sorting-donations-hidden";

// Progress bar for this month's donations, from /discourse-sorting/donations.json.
// Shows totals only. "Hide for now" lasts for the browser session.
export default class DonationThermometer extends Component {
  @service siteSettings;

  @tracked data = null;
  @tracked hidden = this.#readHidden();

  #readHidden() {
    try {
      return sessionStorage.getItem(HIDDEN_KEY) === "1";
    } catch {
      return false;
    }
  }

  get visible() {
    return (
      this.siteSettings.discourse_sorting_donations_enabled &&
      !this.hidden &&
      this.data &&
      this.data.goal_cents > 0
    );
  }

  get percent() {
    const { raised_cents, goal_cents } = this.data;
    return Math.min(100, Math.floor((raised_cents / goal_cents) * 100));
  }

  get reached() {
    return this.data.raised_cents >= this.data.goal_cents;
  }

  get fillStyle() {
    return `width: ${this.percent}%`;
  }

  money(cents) {
    const whole = cents % 100 === 0;
    try {
      return new Intl.NumberFormat(undefined, {
        style: "currency",
        currency: this.data.currency,
        minimumFractionDigits: whole ? 0 : 2,
        maximumFractionDigits: whole ? 0 : 2,
      }).format(cents / 100);
    } catch {
      return `${(cents / 100).toFixed(whole ? 0 : 2)} ${this.data.currency}`;
    }
  }

  get progressText() {
    return i18n("discourse_sorting.donations.progress", {
      raised: this.money(this.data.raised_cents),
      goal: this.money(this.data.goal_cents),
    });
  }

  get percentText() {
    return this.reached
      ? i18n("discourse_sorting.donations.reached")
      : i18n("discourse_sorting.donations.percent", { percent: this.percent });
  }

  @action
  async load() {
    if (!this.siteSettings.discourse_sorting_donations_enabled || this.hidden) {
      return;
    }
    try {
      this.data = await ajax("/discourse-sorting/donations.json");
    } catch {
      // no thermometer is better than an error box
    }
  }

  @action
  hide() {
    this.hidden = true;
    try {
      sessionStorage.setItem(HIDDEN_KEY, "1");
    } catch {
      // private mode: it just comes back on the next page
    }
  }

  <template>
    <div class="donation-thermometer-loader" {{didInsert this.load}}>
      {{#if this.visible}}
        <aside class="donation-thermometer">
          <div class="donation-thermometer__head">
            {{#if this.data.url}}
              <a
                class="donation-thermometer__title"
                href={{this.data.url}}
                target="_blank"
                rel="noopener noreferrer"
              ><strong>{{this.data.title}}</strong></a>
            {{else}}
              <strong class="donation-thermometer__title">{{this.data.title}}</strong>
            {{/if}}
            <span class="donation-thermometer__amounts">{{this.progressText}}</span>
            <button
              type="button"
              class="btn-flat donation-thermometer__hide"
              title={{i18n "discourse_sorting.donations.dismiss"}}
              {{on "click" this.hide}}
            >{{icon "xmark"}}</button>
          </div>
          {{#if this.data.url}}
            <a
              class="donation-thermometer__barlink"
              href={{this.data.url}}
              target="_blank"
              rel="noopener noreferrer"
              aria-label={{this.data.title}}
            ><div
            class="donation-thermometer__bar"
            role="progressbar"
            aria-valuemin="0"
            aria-valuemax="100"
            aria-valuenow={{this.percent}}
          >
            <div class="donation-thermometer__fill" style={{this.fillStyle}}></div>
          </div></a>
          {{else}}
          <div
            class="donation-thermometer__bar"
            role="progressbar"
            aria-valuemin="0"
            aria-valuemax="100"
            aria-valuenow={{this.percent}}
          >
            <div class="donation-thermometer__fill" style={{this.fillStyle}}></div>
          </div>
          {{/if}}
          <div class="donation-thermometer__foot">
            <span>{{this.percentText}}</span>
            {{#if this.data.url}}
              <a
                class="btn btn-primary donation-thermometer__donate"
                href={{this.data.url}}
                target="_blank"
                rel="noopener noreferrer"
              >{{i18n "discourse_sorting.donations.donate"}}</a>
            {{/if}}
          </div>
        </aside>
      {{/if}}
    </div>
  </template>
}
