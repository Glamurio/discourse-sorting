import { apiInitializer } from "discourse/lib/api";
import DonationThermometer from "../components/donation-thermometer";

// The thermometer sits above every topic list (latest, categories, tag pages, /filter).
export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (
    !siteSettings.discourse_sorting_enabled ||
    !siteSettings.discourse_sorting_donations_enabled
  ) {
    return;
  }

  const user = api.getCurrentUser();
  const audience = siteSettings.discourse_sorting_donations_audience;
  const allowed =
    audience === "everyone" ||
    (audience === "staff" ? user?.staff : user?.admin);
  if (!allowed) {
    return;
  }

  api.renderInOutlet("discovery-list-container-top", DonationThermometer);
});
