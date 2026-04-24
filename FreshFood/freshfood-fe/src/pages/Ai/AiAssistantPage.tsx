import React, { useState } from 'react';
import { Sparkles, Utensils, Search, ArrowRight, Loader2, ChefHat, RefreshCw } from 'lucide-react';
import { apiService } from '../../services/api';
import './AiAssistant.css';

export const AiAssistantPage: React.FC = () => {
    const [ingredients, setIngredients] = useState<string>('');
    const [suggestion, setSuggestion] = useState<string | null>(null);
    const [loading, setLoading] = useState<boolean>(false);
    const [error, setError] = useState<string | null>(null);

    const handleSuggest = async () => {
        if (!ingredients.trim()) {
            setError('Vui lòng nhập ít nhất một nguyên liệu!');
            return;
        }

        setLoading(true);
        setError(null);
        setSuggestion(null);

        try {
            const ingredientList = ingredients.split(',').map(s => s.trim()).filter(s => s !== '');
            const result = await apiService.getAiRecipeSuggestion(ingredientList);
            setSuggestion(result);
        } catch (err: any) {
            setError(err.message || 'Đã có lỗi xảy ra khi gọi AI.');
        } finally {
            setLoading(false);
        }
    };

    const formatMarkdown = (text: string) => {
        return text.split('\n').map((line, i) => {
            // Simple bold parsing: **text**
            let formattedLine = line.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
            
            // Simple list parsing: 1. or -
            if (/^\d+\./.test(line)) {
                return <p key={i} className="ai-list-item" dangerouslySetInnerHTML={{ __html: formattedLine }} />;
            }
            if (line.startsWith('#')) {
                return <h3 key={i} className="ai-heading" dangerouslySetInnerHTML={{ __html: formattedLine.replace(/#/g, '') }} />;
            }
            return <p key={i} className="ai-text" dangerouslySetInnerHTML={{ __html: formattedLine }} />;
        });
    };

    return (
        <div className="ai-page-container">
            <div className="ai-hero-section">
                <div className="ai-badge">
                    <Sparkles size={14} className="sparkle-icon" />
                    <span>Powered by OpenAI</span>
                </div>
                <h1>Hôm nay ăn gì?</h1>
                <p>Nhập các nguyên liệu bạn có, Trợ lý AI FreshFood sẽ gợi ý món ăn hoàn hảo cho bạn.</p>
            </div>

            <div className="ai-content-wrapper">
                <div className="ai-input-card">
                    <div className="input-header">
                        <Utensils size={20} />
                        <span>Nguyên liệu hiện có</span>
                    </div>
                    <textarea
                        placeholder="Ví dụ: Cá lóc, cà chua, dứa, hành lá..."
                        value={ingredients}
                        onChange={(e) => setIngredients(e.target.value)}
                        disabled={loading}
                    />
                    <div className="input-footer">
                        <p>Phân cách các nguyên liệu bằng dấu phẩy</p>
                        <button 
                            className={`ai-btn-primary ${loading ? 'loading' : ''}`}
                            onClick={handleSuggest}
                            disabled={loading}
                        >
                            {loading ? (
                                <>
                                    <Loader2 className="animate-spin" size={20} />
                                    Đang suy nghĩ...
                                </>
                            ) : (
                                <>
                                    Gợi ý ngay
                                    <ArrowRight size={18} />
                                </>
                            )}
                        </button>
                    </div>
                </div>

                {error && (
                    <div className="ai-error-box">
                        <p>{error}</p>
                    </div>
                )}

                {suggestion && (
                    <div className="ai-result-container animate-fade-in">
                        <div className="ai-result-card">
                            <div className="result-header">
                                <ChefHat size={24} className="chef-icon" />
                                <h2>Gợi ý từ Đầu bếp AI</h2>
                                <button className="btn-refresh" onClick={handleSuggest}>
                                    <RefreshCw size={16} />
                                    Thử món khác
                                </button>
                            </div>
                            <div className="result-body">
                                {formatMarkdown(suggestion)}
                            </div>
                        </div>
                        
                        <div className="ai-cta-box">
                            <p>Bạn chưa có đủ nguyên liệu? Ghé thăm cửa hàng ngay!</p>
                            <button className="ai-btn-secondary" onClick={() => window.location.href='/products'}>
                                Đến cửa hàng FreshFood
                            </button>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
};
