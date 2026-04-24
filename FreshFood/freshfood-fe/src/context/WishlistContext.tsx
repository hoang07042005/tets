import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import type { WishlistItem } from '../types';
import { apiService } from '../services/api';
import { useAuth } from './AuthContext';

type WishlistContextType = {
  items: WishlistItem[];
  productIdSet: Set<number>;
  loading: boolean;
  refresh: () => Promise<void>;
  isWished: (productId: number) => boolean;
  toggle: (productId: number) => Promise<void>;
};

const WishlistContext = createContext<WishlistContextType | undefined>(undefined);

export const WishlistProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user, isAuthenticated } = useAuth();
  const [items, setItems] = useState<WishlistItem[]>([]);
  const [loading, setLoading] = useState(false);

  const refresh = async () => {
    if (!isAuthenticated || !user) {
      setItems([]);
      return;
    }
    setLoading(true);
    try {
      const data = await apiService.getWishlist(user.userID);
      setItems(data || []);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isAuthenticated, user?.userID]);

  const productIdSet = useMemo(() => new Set(items.map((x) => x.productID)), [items]);

  const isWished = (productId: number) => productIdSet.has(productId);

  const toggle = async (productId: number) => {
    if (!isAuthenticated || !user) return;
    await apiService.toggleWishlist({ userID: user.userID, productID: productId });
    await refresh();
  };

  return (
    <WishlistContext.Provider value={{ items, productIdSet, loading, refresh, isWished, toggle }}>
      {children}
    </WishlistContext.Provider>
  );
};

export const useWishlist = () => {
  const ctx = useContext(WishlistContext);
  if (!ctx) throw new Error('useWishlist must be used within a WishlistProvider');
  return ctx;
};

