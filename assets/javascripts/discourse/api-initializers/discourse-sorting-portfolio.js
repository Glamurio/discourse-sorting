import { apiInitializer } from "discourse/lib/api";

// The User Portfolio theme component (discourse/discourse-user-portfolio) builds its
// topic list in route:user.portfolio (file routes/user/portfolio) and always sends
// the `portfolio_order` theme setting, ignoring the page URL. The server already
// honours `order` and `ascending` on /topics/created-by/:username, so this only
// forwards them from the URL.
//
// modifyClass copies the methods, getters and setters of the class returned by the
// callback onto the existing class; it does NOT apply class fields (`foo = 1`) or
// constructors. So everything below is a method, getter or setter.
//
// If the component is not installed, the class lookup finds nothing and
// modifyClass defers the change, so this is a harmless no-op.
const ALLOWED_ORDERS = [
  "created",
  "activity",
  "likes",
  "op_likes",
  "views",
  "posts",
  "posters",
  "category",
];

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (
    !siteSettings.discourse_sorting_enabled ||
    !siteSettings.discourse_sorting_portfolio_params
  ) {
    return;
  }

  // Make `order` and `ascending` real query parameters of the page.
  api.modifyClass(
    "controller:user.portfolio",
    (Superclass) =>
      class extends Superclass {
        get queryParams() {
          return ["order", "ascending"];
        }

        get order() {
          return this._discourseSortingOrder ?? null;
        }

        set order(value) {
          this._discourseSortingOrder = value;
        }

        get ascending() {
          return this._discourseSortingAscending ?? null;
        }

        set ascending(value) {
          this._discourseSortingAscending = value;
        }
      }
  );

  api.modifyClass(
    "route:user.portfolio",
    (Superclass) =>
      class extends Superclass {
        get queryParams() {
          return {
            order: { refreshModel: true },
            ascending: { refreshModel: true },
          };
        }

        model(params, transition) {
          // `params` carries declared query parameters; the transition's own query
          // parameters are the fallback should the declaration not take effect.
          const urlParams = transition?.to?.queryParams || {};
          const wantedOrder = params?.order ?? urlParams.order;
          const wantedAscending = params?.ascending ?? urlParams.ascending;

          const order = ALLOWED_ORDERS.includes(wantedOrder)
            ? wantedOrder
            : null;
          const ascending = String(wantedAscending) === "true" ? "true" : null;

          if (!order && !ascending) {
            return super.model(...arguments);
          }

          // The component's model() calls store.findFiltered() synchronously.
          // Wrap it for that single call so its tag/category settings are kept.
          const store = this.store;
          const original = store.findFiltered;
          store.findFiltered = function (type, findArgs) {
            const extra = {};
            if (order) {
              extra.order = order;
            }
            if (ascending) {
              extra.ascending = ascending;
            }
            return original.call(this, type, {
              ...findArgs,
              params: { ...findArgs.params, ...extra },
            });
          };

          try {
            return super.model(...arguments);
          } finally {
            store.findFiltered = original;
          }
        }
      }
  );
});
