import { LightningElement, wire } from "lwc";
import getProducts from "@salesforce/apex/FashionShowcaseController.getProducts";
import VividEditImages from "@salesforce/resourceUrl/VividEditImages";

const CATEGORIES = [
  { key: "Trending", label: "New & Trending" },
  { key: "All", label: "All Collection" },
  { key: "Men", label: "Men" },
  { key: "Women", label: "Women" },
  { key: "Unisex", label: "Unisex" },
];

const SORT_OPTIONS = [
  { value: "featured", label: "Featured" },
  { value: "newest", label: "Newest first" },
  { value: "price-asc", label: "Price: Low to high" },
  { value: "price-desc", label: "Price: High to low" },
];

const OFFER_TILES = [
  {
    eyebrow: "The new season",
    title: "New arrivals",
    detail: "Discover the latest collection",
    tone: "coral",
  },
  {
    eyebrow: "The Vivid Circle",
    title: "Member privileges",
    detail: "Early access & private edits",
    tone: "teal",
  },
  {
    eyebrow: "Made to last",
    title: "Easy returns",
    detail: "A simple 7-day return policy",
    tone: "gold",
  },
];

const HERO_CATEGORY_TILES = [
  {
    key: "Women",
    icon: "W",
    title: "The Women's Edit",
    offerPrefix: "NEW",
    offerHighlight: "SEASON",
    offerSuffix: "NOW",
    tone: "coral",
  },
  {
    key: "Men",
    icon: "M",
    title: "The Men's Edit",
    offerPrefix: "MODERN",
    offerHighlight: "ESSENTIALS",
    offerSuffix: "",
    tone: "blue",
  },
  {
    key: "Unisex",
    icon: "U",
    title: "Unisex Collection",
    offerPrefix: "DESIGNED",
    offerHighlight: "FOR",
    offerSuffix: "ALL",
    tone: "yellow",
  },
  {
    key: "All",
    icon: "A",
    title: "Accessories",
    offerPrefix: "THE",
    offerHighlight: "FINAL",
    offerSuffix: "DETAIL",
    tone: "aqua",
  },
];

// NOTE: kept exactly as-is per request, including wording and order.
const CAMPAIGN_TICKER = [
  "COMPLIMENTARY SHIPPING ON ORDERS OVER RS. 999",
  "THE NEW SEASON HAS ARRIVED",
  "7-DAY EASY RETURNS",
  "CURATED FOR MODERN EVERYDAY DRESSING",
  "NEW EDITS RELEASED REGULARLY",
];

const COLOR_SWATCHES = {
  black: "#171717",
  white: "#f8f7f4",
  ivory: "#f3ead9",
  cream: "#f0e6d2",
  beige: "#d9c7a6",
  tan: "#c9a374",
  brown: "#6b4a34",
  grey: "#9c968c",
  gray: "#9c968c",
  charcoal: "#3a3733",
  navy: "#1f2f4d",
  blue: "#3d6aa8",
  "sky blue": "#8ec6e6",
  teal: "#2f6f63",
  green: "#3f7d4f",
  olive: "#6f7548",
  yellow: "#e8c04a",
  mustard: "#c99a2e",
  gold: "#b98a3d",
  orange: "#e07a3e",
  rust: "#b1502e",
  red: "#b2372c",
  maroon: "#742735",
  pink: "#e3a0ac",
  "blush pink": "#e6b9bd",
  magenta: "#c23b7a",
  purple: "#6a4c8c",
  lavender: "#b9a7d6",
  silver: "#c7c4bc",
  multicolor: "linear-gradient(135deg,#e4472c,#2f6f63,#b98a3d)",
};


const ONLINE_ASSETS = {
  hero: `${VividEditImages}/hero.jpg`,
  women: `${VividEditImages}/women.jpg`,
  men: `${VividEditImages}/men.jpg`,
  accessories: `${VividEditImages}/accessories.jpg`,
  sale: `${VividEditImages}/sale.jpg`,
  editorial1: `${VividEditImages}/editorial1.jpg`,
  editorial2: `${VividEditImages}/editorial2.jpg`,
  product1: `${VividEditImages}/product1.jpg`,
  product2: `${VividEditImages}/product2.jpg`,
  product3: `${VividEditImages}/product3.jpg`,
  product4: `${VividEditImages}/product4.jpg`,
  product5: `${VividEditImages}/product5.jpg`,
  product6: `${VividEditImages}/product6.jpg`
};

const WISHLIST_KEY = "vividedit.wishlist";
const CART_KEY = "vividedit.cart";
const TOAST_DURATION = 2600;

export default class MyntraRetailStorefront extends LightningElement {
  categoryKey = "Trending";
  rawProducts = [];
  isLoading = true;
  errorMessage = "";
  sortBy = "featured";
  searchTerm = "";
  isSearchOpen = false;
  isCartOpen = false;
  isNavOpen = false;
  isScrolled = false;
  quickViewId = null;
  isWishlistOpen = false;
  maxResults = 6;
  wishlistIds = new Set();
  cartItems = [];
  toastMessage = "";
  toastTone = "default";

  _toastTimer;
  _scrollTicking = false;
  _boundScroll;
  _boundKeydown;

  connectedCallback() {
    this.restoreFromStorage();
    this._boundScroll = this.handleWindowScroll.bind(this);
    this._boundKeydown = this.handleWindowKeydown.bind(this);
    window.addEventListener("scroll", this._boundScroll, { passive: true });
    window.addEventListener("keydown", this._boundKeydown);
  }

  disconnectedCallback() {
    window.removeEventListener("scroll", this._boundScroll);
    window.removeEventListener("keydown", this._boundKeydown);
    window.clearTimeout(this._toastTimer);
  }

  @wire(getProducts, { category: "$categoryKey", maxResults: "$maxResults" })
  wiredProducts({ data, error }) {
    if (data) {
      this.rawProducts = data.map((row, index) => this.decorateProduct(row, index));
      this.errorMessage = "";
      this.isLoading = false;
    } else if (error) {
      this.rawProducts = [];
      this.errorMessage = this.reduceError(error);
      this.isLoading = false;
    }
  }

  // ---------- static content ----------

  get categories() {
    return CATEGORIES.map((category) => ({
      ...category,
      className: `category-tab${category.key === this.categoryKey ? " is-active" : ""}`,
      ariaSelected: category.key === this.categoryKey,
    }));
  }

  get sortOptions() {
    return SORT_OPTIONS;
  }

  get offers() {
    return OFFER_TILES;
  }

  get campaignTicker() {
    return [...CAMPAIGN_TICKER, ...CAMPAIGN_TICKER].map((label, index) => ({
      id: `${label}-${index}`,
      label,
    }));
  }

  get heroCategories() {
    return [
      { key: "Women", title: "Women", offerPrefix: "DISCOVER", offerHighlight: "NEW", offerSuffix: "STYLES", tone: "coral", imageUrl: ONLINE_ASSETS.women },
      { key: "Men", title: "Men", offerPrefix: "MODERN", offerHighlight: "ESSENTIALS", offerSuffix: "", tone: "blue", imageUrl: ONLINE_ASSETS.men },
      { key: "All", title: "Accessories", offerPrefix: "COMPLETE", offerHighlight: "YOUR", offerSuffix: "LOOK", tone: "cream", imageUrl: ONLINE_ASSETS.accessories },
      { key: "All", title: "Sale", offerPrefix: "UP TO", offerHighlight: "50%", offerSuffix: "OFF", tone: "coral", imageUrl: ONLINE_ASSETS.sale },
    ];
  }

  get bannerAssets() { return ONLINE_ASSETS; }

  get skeletonCards() { return [1,2,3,4,5,6]; }

  get keepShopping() {
    return CATEGORIES.filter((category) => category.key !== "Trending" && category.key !== "All").map(
      (category, index) => {
        const product =
          this.rawProducts.find((item) => item.gender === category.key) || this.rawProducts[index];
        return {
          ...category,
          imageUrl: product?.imageUrl,
          hasImage: Boolean(product?.imageUrl),
          subtitle: product?.name || `Explore ${category.label.toLowerCase()}`,
          className: `collection-card collection-${index + 1}`,
        };
      },
    );
  }

  // ---------- header state ----------

  get headerClassName() {
    return `site-header${this.isScrolled ? " is-scrolled" : ""}`;
  }

  get navDrawerClassName() {
    return `nav-drawer${this.isNavOpen ? " is-open" : ""}`;
  }

  get wishlistCount() {
    return this.wishlistIds.size;
  }

  get hasWishlist() {
    return this.wishlistCount > 0;
  }

  get isWishlistVisible() {
    return this.isWishlistOpen;
  }

  get wishlistProducts() {
    return this.rawProducts
      .filter((product) => this.wishlistIds.has(product.id))
      .map((product) => ({
        ...product,
        wishlistClass: "wishlist-button is-active",
      }));
  }

  get hasWishlistProducts() {
    return this.wishlistProducts.length > 0;
  }

  get canLoadMore() {
    return !this.isLoading && this.rawProducts.length >= this.maxResults;
  }

  get cartCount() {
    return this.cartItems.reduce((sum, item) => sum + item.qty, 0);
  }

  get hasCartItems() {
    return this.cartItems.length > 0;
  }

  get cartSubtotalLabel() {
    const total = this.cartItems.reduce((sum, item) => sum + item.price * item.qty, 0);
    return this.formatPrice(total);
  }

  get cartLineItems() {
    return this.cartItems.map((item) => ({
      ...item,
      priceLabel: this.formatPrice(item.price),
      lineTotalLabel: this.formatPrice(item.price * item.qty),
    }));
  }

  // ---------- catalog ----------

  get decoratedProducts() {
    const term = this.searchTerm.trim().toLowerCase();
    let list = this.rawProducts;

    if (term) {
      list = list.filter(
        (product) =>
          product.name.toLowerCase().includes(term) ||
          product.brandLabel.toLowerCase().includes(term) ||
          product.colorLabel.toLowerCase().includes(term),
      );
    }

    list = [...list];
    if (this.sortBy === "price-asc") {
      list.sort((a, b) => (a.price ?? 0) - (b.price ?? 0));
    } else if (this.sortBy === "price-desc") {
      list.sort((a, b) => (b.price ?? 0) - (a.price ?? 0));
    } else if (this.sortBy === "newest") {
      list.sort((a, b) => (b.launchTimestamp ?? 0) - (a.launchTimestamp ?? 0));
    }

    return list.map((product) => ({
      ...product,
      isWishlisted: this.wishlistIds.has(product.id),
      wishlistClass: `wishlist-button${this.wishlistIds.has(product.id) ? " is-active" : ""}`,
    }));
  }

  get featuredProducts() {
    return this.rawProducts.slice(0, 6).map((product) => ({
      ...product,
      isWishlisted: this.wishlistIds.has(product.id),
    }));
  }

  get editorialProducts() {
    const unique = [];
    const seen = new Set();
    for (const product of this.rawProducts) {
      if (product?.imageUrl && !seen.has(product.imageUrl)) {
        seen.add(product.imageUrl);
        unique.push(product);
      }
      if (unique.length === 2) break;
    }
    return unique;
  }

  get editorialFirst() {
    return this.editorialProducts[0] || null;
  }

  get editorialSecond() {
    return this.editorialProducts[1] || null;
  }

  get hasProducts() {
    return this.decoratedProducts.length > 0;
  }

  get hasError() {
    return Boolean(this.errorMessage);
  }

  get hasSearchTerm() {
    return this.searchTerm.trim().length > 0;
  }

  get resultCountLabel() {
    if (this.isLoading) {
      return "Finding your next look";
    }
    const count = this.decoratedProducts.length;
    return `${count} style${count === 1 ? "" : "s"} curated for you`;
  }

  get quickViewProduct() {
    if (!this.quickViewId) {
      return null;
    }
    const product = this.rawProducts.find((item) => item.id === this.quickViewId);
    if (!product) {
      return null;
    }
    const isWishlisted = this.wishlistIds.has(product.id);
    return {
      ...product,
      isWishlisted,
      wishlistClass: `wishlist-button pill${isWishlisted ? " is-active" : ""}`,
      colorSwatchStyle: product.colorSwatch ? `background:${product.colorSwatch};` : "",
    };
  }

  get currentYear() {
    return `${new Date().getFullYear()} `;
  }

  get isQuickViewOpen() {
    return Boolean(this.quickViewProduct);
  }

  get toastClassName() {
    return `toast toast-${this.toastTone}${this.toastMessage ? " is-visible" : ""}`;
  }

  get hasToast() {
    return Boolean(this.toastMessage);
  }

  handleNewsletterSubmit(event) {
    event.preventDefault();
    event.target.reset();
    this.showToast("Welcome to the VIVID/EDIT list");
  }

  // ---------- handlers: navigation ----------

  handleCategoryClick(event) {
    const nextCategory = event.currentTarget.dataset.key;
    this.isNavOpen = false;
    this.isSearchOpen = false;
    if (nextCategory === this.categoryKey) {
      this.scrollToCatalog();
      return;
    }
    this.isLoading = true;
    this.maxResults = 12;
    this.categoryKey = nextCategory;
    this.scrollToCatalog();
  }

 scrollToCatalog() {
    setTimeout(() => {
        const section = this.template.querySelector(".catalog");

        if (section) {
            section.scrollIntoView({
                behavior: "smooth",
                block: "start"
            });
        }
    }, 0);
}

  toggleNavDrawer() {
    this.isNavOpen = !this.isNavOpen;
  }

  closeNavDrawer() {
    this.isNavOpen = false;
  }

  toggleSearch() {
    this.isSearchOpen = !this.isSearchOpen;
    if (this.isSearchOpen) {
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(() => {
        const input = this.template.querySelector(".search-input");
        if (input) {
          input.focus();
        }
      }, 0);
    }
  }

  closeSearch() {
    this.isSearchOpen = false;
  }

  handleSearchInput(event) {
    this.searchTerm = event.target.value;
  }

  clearSearch() {
    this.searchTerm = "";
  }

  handleSearchSubmit(event) {
    event.preventDefault();
    this.isSearchOpen = false;
    this.scrollToCatalog();
  }

  handleSortChange(event) {
    this.sortBy = event.target.value;
  }

  // ---------- handlers: wishlist ----------

  toggleWishlist(event) {
    event.stopPropagation();
    const id = event.currentTarget.dataset.id;
    const next = new Set(this.wishlistIds);
    let added = false;
    if (next.has(id)) {
      next.delete(id);
    } else {
      next.add(id);
      added = true;
    }
    this.wishlistIds = next;
    this.persist(WISHLIST_KEY, [...next]);
    this.showToast(added ? "Added to wishlist" : "Removed from wishlist");
  }

  // ---------- handlers: wishlist drawer ----------

  toggleWishlistDrawer() {
    this.isWishlistOpen = !this.isWishlistOpen;
    this.isCartOpen = false;
    this.isSearchOpen = false;
  }

  closeWishlistDrawer() {
    this.isWishlistOpen = false;
  }

  addWishlistProductToBag(event) {
    event.stopPropagation();
    const id = event.currentTarget.dataset.id;
    this.addProductToCart(id, 1);
    this.showToast("Added to bag");
  }

  handleWishlistContinue(event) {
    this.closeWishlistDrawer();
    this.handleCategoryClick(event);
  }

  loadMoreProducts() {
    if (!this.canLoadMore) {
      return;
    }
    this.isLoading = true;
    this.maxResults += 12;
  }

  // ---------- handlers: cart ----------

  addToBag(event) {
    event.stopPropagation();
    const id = event.currentTarget.dataset.id;
    this.addProductToCart(id, 1);
    this.showToast("Added to bag");
  }

  addProductToCart(id, qty) {
    const product = this.rawProducts.find((item) => item.id === id);
    if (!product) {
      return;
    }
    const existing = this.cartItems.find((item) => item.id === id);
    let next;
    if (existing) {
      next = this.cartItems.map((item) =>
        item.id === id ? { ...item, qty: item.qty + qty } : item,
      );
    } else {
      next = [
        ...this.cartItems,
        {
          id: product.id,
          name: product.name,
          brandLabel: product.brandLabel,
          imageUrl: product.imageUrl,
          hasImage: product.hasImage,
          price: product.price ?? 0,
          qty,
        },
      ];
    }
    this.cartItems = next;
    this.persist(CART_KEY, next);
  }

  incrementCartItem(event) {
    const id = event.currentTarget.dataset.id;
    const next = this.cartItems.map((item) => (item.id === id ? { ...item, qty: item.qty + 1 } : item));
    this.cartItems = next;
    this.persist(CART_KEY, next);
  }

  decrementCartItem(event) {
    const id = event.currentTarget.dataset.id;
    const next = this.cartItems
      .map((item) => (item.id === id ? { ...item, qty: item.qty - 1 } : item))
      .filter((item) => item.qty > 0);
    this.cartItems = next;
    this.persist(CART_KEY, next);
  }

  removeCartItem(event) {
    const id = event.currentTarget.dataset.id;
    const next = this.cartItems.filter((item) => item.id !== id);
    this.cartItems = next;
    this.persist(CART_KEY, next);
  }

  toggleCart() {
    this.isCartOpen = !this.isCartOpen;
  }

  closeCart() {
    this.isCartOpen = false;
  }

  handleCheckout() {
    this.showToast("Checkout isn't wired up in this preview yet");
  }

  // ---------- handlers: quick view ----------

  openQuickView(event) {
    this.quickViewId = event.currentTarget.dataset.id;
  }

  closeQuickView() {
    this.quickViewId = null;
  }

  addQuickViewToBag() {
    if (this.quickViewId) {
      this.addProductToCart(this.quickViewId, 1);
      this.showToast("Added to bag");
    }
  }

  // ---------- handlers: image ----------

  handleImageError(event) {
    event.target.hidden = true;
    event.target.parentElement.classList.add("image-fallback");
  }

  // ---------- global listeners ----------

  handleWindowScroll() {
    if (this._scrollTicking) {
      return;
    }
    this._scrollTicking = true;
    window.requestAnimationFrame(() => {
      this.isScrolled = window.scrollY > 12;
      this._scrollTicking = false;
    });
  }

  handleWindowKeydown(event) {
    if (event.key === "Escape") {
      this.closeQuickView();
      this.closeCart();
      this.closeSearch();
      this.closeNavDrawer();
      this.closeWishlistDrawer();
    }
  }

  handleOverlayClick(event) {
    if (event.target === event.currentTarget) {
      this.closeQuickView();
      this.closeCart();
      this.closeSearch();
      this.closeWishlistDrawer();
    }
  }

  // ---------- data helpers ----------

  decorateProduct(row, index) {
    const launchTimestamp = row.launchDate ? new Date(row.launchDate).getTime() : 0;
    const onlineFallbacks = [ONLINE_ASSETS.product1, ONLINE_ASSETS.product2, ONLINE_ASSETS.product3, ONLINE_ASSETS.product4, ONLINE_ASSETS.product5, ONLINE_ASSETS.product6, ONLINE_ASSETS.women, ONLINE_ASSETS.men];
    const duplicateImage = row.imageUrl && this.rawProducts.some((item) => item.imageUrl === row.imageUrl);
    const finalImage = row.imageUrl && !duplicateImage ? row.imageUrl : onlineFallbacks[index % onlineFallbacks.length];
    return {
      ...row,
      imageUrl: finalImage,
      hasImage: Boolean(finalImage),
      mediaClass: `product-image-wrap${finalImage ? "" : " image-fallback"}`,
      brandLabel: row.brand || "Studio edit",
      colorLabel: row.color || "Signature color",
      colorSwatch: this.resolveColorSwatch(row.color),
      priceLabel: this.formatPrice(row.price),
      launchLabel: row.launchDate ? this.formatDate(row.launchDate) : "Just in",
      launchTimestamp,
      badgeLabel: (row.rank ?? index + 1) <= 3 ? "Bestseller" : row.season ? `${row.season} drop` : "New in",
      styleCode: row.productCode || row.id,
    };
  }

  resolveColorSwatch(colorName) {
    if (!colorName) {
      return "";
    }
    const key = colorName.trim().toLowerCase();
    return COLOR_SWATCHES[key] || "";
  }

  formatPrice(value) {
    if (value === null || value === undefined) {
      return "Price on request";
    }
    return new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: "INR",
      maximumFractionDigits: 0,
    }).format(value);
  }

  formatDate(value) {
    return new Intl.DateTimeFormat("en-IN", {
      month: "short",
      day: "numeric",
    }).format(new Date(value));
  }

  reduceError(error) {
    if (Array.isArray(error?.body)) {
      return error.body.map((item) => item.message).join(", ");
    }
    return (
      error?.body?.message || error?.message || "The catalog is taking a moment. Please try again."
    );
  }

  showToast(message, tone = "default") {
    window.clearTimeout(this._toastTimer);
    this.toastMessage = message;
    this.toastTone = tone;
    this._toastTimer = window.setTimeout(() => {
      this.toastMessage = "";
    }, TOAST_DURATION);
  }

  persist(key, value) {
    try {
      window.localStorage.setItem(key, JSON.stringify(value));
    } catch (e) {
      // storage unavailable (private browsing, locked-down session) - fail silently
    }
  }

  restoreFromStorage() {
    try {
      const wishlist = window.localStorage.getItem(WISHLIST_KEY);
      if (wishlist) {
        this.wishlistIds = new Set(JSON.parse(wishlist));
      }
    } catch (e) {
      this.wishlistIds = new Set();
    }
    try {
      const cart = window.localStorage.getItem(CART_KEY);
      if (cart) {
        this.cartItems = JSON.parse(cart);
      }
    } catch (e) {
      this.cartItems = [];
    }
  }
}