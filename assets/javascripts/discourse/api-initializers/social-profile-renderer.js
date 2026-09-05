import { apiInitializer } from "discourse/lib/api";
import SocialProfileIcons from "../components/social-profile-icons";

export default apiInitializer((api) => {
  api.renderInOutlet("user-post-names", SocialProfileIcons);
  api.renderInOutlet("user-card-post-names", SocialProfileIcons);
});
