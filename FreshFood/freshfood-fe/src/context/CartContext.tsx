import React, { createContext, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { Product } from '../types';
import { apiService } from '../services/api';
import { useAuth } from './AuthContext';

interface CartItem {
  product: Product;
  quantity: number;
}

interface CartContextType {
  cart: CartItem[];
  addToCart: (product: Product, quantity?: number) => void;
  removeFromCart: (productId: number) => void;
  updateQuantity: (productId: number, quantity: number) => void;
  clearCart: () => void;
  totalItems: number;
  totalPrice: number;
}

const CartContext = createContext<CartContextType | undefined>(undefined);

export const CartProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user, isAuthenticated } = useAuth();
  const [cart, setCart] = useState<CartItem[]>(() => {
    try {
      const savedCart = localStorage.getItem('freshfood_cart');
      return savedCart ? (JSON.parse(savedCart) as CartItem[]) : [];
    } catch {
      return [];
    }
  });

  useEffect(() => {
    // Product objects from API can contain nested references (category.products, reviews...)
    // which may create circular structures and crash JSON.stringify -> blank screen.
    // Persist a lightweight cart snapshot instead.
    try {
      const safeCart = cart.map((ci) => ({
        product: normalizeProductForCart(ci.product),
        quantity: ci.quantity,
      }));
      localStorage.setItem('freshfood_cart', JSON.stringify(safeCart));
    } catch {
      // ignore persistence errors; keep cart in memory
    }
  }, [cart]);

  const syncingRef = useRef(false);
  const hydrateDoneRef = useRef(false);
  const syncTimerRef = useRef<number | null>(null);

  // When user logs in, load cart from DB (server is source of truth).
  useEffect(() => {
    const uid = user?.userID;
    if (!isAuthenticated || !uid) {
      hydrateDoneRef.current = false;
      return;
    }
    let ignore = false;
    (async () => {
      try {
        const dto = await apiService.getUserCart(uid);
        if (ignore) return;
        const items = (dto?.items || []).map((x) => ({ product: x.product, quantity: x.quantity }));
        syncingRef.current = true;
        setCart(items);
        // mark hydrated after we set cart
        hydrateDoneRef.current = true;
      } catch {
        hydrateDoneRef.current = true;
      } finally {
        // allow sync after hydration settles
        window.setTimeout(() => {
          syncingRef.current = false;
        }, 0);
      }
    })();
    return () => {
      ignore = true;
    };
  }, [isAuthenticated, user?.userID]);

  // Debounced sync to server whenever cart changes (authenticated only).
  useEffect(() => {
    const uid = user?.userID;
    if (!isAuthenticated || !uid) return;
    if (!hydrateDoneRef.current) return;
    if (syncingRef.current) return;

    if (syncTimerRef.current) window.clearTimeout(syncTimerRef.current);
    syncTimerRef.current = window.setTimeout(() => {
      const payload = cart.map((ci) => ({ productID: ci.product.productID, quantity: ci.quantity }));
      apiService.replaceUserCart(uid, payload).catch(() => {
        // ignore sync errors; UI remains functional with local cart
      });
    }, 400);

    return () => {
      if (syncTimerRef.current) window.clearTimeout(syncTimerRef.current);
    };
  }, [cart, isAuthenticated, user?.userID]);

  const normalizeProductForCart = (p: Product): Product => {
    // Keep only fields needed for cart UI/checkout; avoid nested graphs that can be circular.
    return {
      productID: p.productID,
      productToken: p.productToken ?? null,
      productName: p.productName,
      sku: p.sku ?? null,
      categoryID: p.categoryID,
      supplierID: p.supplierID,
      price: p.price,
      discountPrice: p.discountPrice,
      stockQuantity: p.stockQuantity,
      unit: p.unit,
      description: p.description,
      manufacturedDate: p.manufacturedDate ?? null,
      expiryDate: p.expiryDate ?? null,
      origin: p.origin ?? null,
      storageInstructions: p.storageInstructions ?? null,
      certifications: p.certifications ?? null,
      createdAt: p.createdAt,
      productImages: Array.isArray(p.productImages) ? p.productImages : [],
      reviews: [], // never persist full reviews in cart
      averageRating: p.averageRating,
      reviewCount: p.reviewCount,
      category: undefined,
      supplier: undefined,
    } as Product;
  };

  const addToCart = (product: Product, quantity: number = 1) => {
    const qty = Number.isFinite(quantity) ? Math.max(1, Math.floor(quantity)) : 1;
    const safeProduct = normalizeProductForCart(product);
    setCart(prev => {
      const existing = prev.find(item => item.product.productID === safeProduct.productID);
      if (existing) {
        return prev.map(item =>
          item.product.productID === safeProduct.productID
            ? { ...item, quantity: item.quantity + qty }
            : item
        );
      }
      return [...prev, { product: safeProduct, quantity: qty }];
    });
  };

  const removeFromCart = (productId: number) => {
    setCart(prev => prev.filter(item => item.product.productID !== productId));
  };

  const updateQuantity = (productId: number, quantity: number) => {
    if (quantity < 1) return;
    setCart(prev =>
      prev.map(item =>
        item.product.productID === productId ? { ...item, quantity } : item
      )
    );
  };

  const clearCart = () => setCart([]);

  const totalItems = cart.reduce((sum, item) => sum + item.quantity, 0);
  const totalPrice = useMemo(() => {
    return cart.reduce((sum, item) => {
      const sell = item.product.discountPrice != null && item.product.discountPrice < item.product.price ? item.product.discountPrice : item.product.price;
      return sum + sell * item.quantity;
    }, 0);
  }, [cart]);

  return (
    <CartContext.Provider value={{ 
      cart, addToCart, removeFromCart, updateQuantity, clearCart, totalItems, totalPrice 
    }}>
      {children}
    </CartContext.Provider>
  );
};

export const useCart = () => {
  const context = useContext(CartContext);
  if (!context) throw new Error('useCart must be used within a CartProvider');
  return context;
};
