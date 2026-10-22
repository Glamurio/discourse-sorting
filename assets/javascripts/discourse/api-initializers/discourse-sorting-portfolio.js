import { apiInitializer } from "discourse/lib/api";

// The User Portfolio theme component (discourse/discourse-user-portfolio) builds its
// topic list in route:user.portfolio (file routes/user/portfolio) and always sends
// the `portfolio_order` theme setting,
// ignoring the page URL. The server already honours `order` and `ascending` on
// /topics/created-by/:username, so this only forwards them from the URL.
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

  api.modifyClass(
    "controller:user.portfolio",
    (Superclass) =>
      class extends Superclass {
        queryParams = ["order", "ascending"];
        order = null;
        ascending = null;
      }
  );

  api.modifyClass(
    "route:user.portfolio",
    (Superclass) =>
      class extends Superclass {
        queryParams = {
          order: { refreshModel: true },
          ascending: { refreshModel: true },
        };

        model(params) {
          const order = ALLOWED_ORDERS.includes(params?.order)
            ? params.order
            : null;
          const ascending = params?.ascending === "true" ? "true" : null;

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
