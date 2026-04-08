import React, { useEffect, useState } from 'react';
import styles from './Quiz.module.css';

/**
 * <Quiz lessonId="01-fundamentals" questions={[...]} />
 *
 * questions: Array<{
 *   type: 'mcq' | 'fill',
 *   prompt: string,
 *   choices?: string[],   // mcq only
 *   answer: string,       // mcq: the correct choice; fill: case-insensitive expected text
 *   explanation?: string,
 * }>
 *
 * Behavior:
 *   - MCQ: học viên có thể chọn lại các đáp án khác khi chọn sai, cho tới khi
 *     chọn đúng thì câu hỏi mới được khoá. Điểm chỉ được cộng nếu trả lời
 *     đúng ngay lần thử đầu tiên.
 *   - Fill: chỉ chấm 1 lần khi nhấn "Kiểm tra".
 *
 * Score và completion được lưu vào localStorage tại key
 * `vault-course:quiz:<lessonId>` để học viên thấy lại tiến độ giữa các lần truy cập.
 */
export default function Quiz({ lessonId, questions = [] }) {
  const storageKey = `vault-course:quiz:${lessonId}`;
  const [index, setIndex] = useState(0);
  const [picked, setPicked] = useState(null);          // mcq: lựa chọn hiện tại; fill: 'submitted' khi đã chấm
  const [wrongPicks, setWrongPicks] = useState([]);    // mcq: danh sách các lựa chọn sai đã thử
  const [solved, setSolved] = useState(false);         // câu hiện tại đã trả lời đúng / đã nộp (fill)
  const [fillValue, setFillValue] = useState('');
  const [score, setScore] = useState(0);
  const [done, setDone] = useState(false);

  // Restore previous best score on mount.
  useEffect(() => {
    if (typeof window === 'undefined') return;
    const raw = window.localStorage.getItem(storageKey);
    if (raw) {
      try {
        const prev = JSON.parse(raw);
        if (prev?.completed) setDone(true);
      } catch {}
    }
  }, [storageKey]);

  if (questions.length === 0) {
    return <p><em>Chưa có câu hỏi nào cho bài kiểm tra này.</em></p>;
  }

  const q = questions[index];
  const isLast = index === questions.length - 1;

  function pickMcq(choice) {
    if (solved) return;                  // câu đã đúng, không cho click nữa
    if (wrongPicks.includes(choice)) return; // đã thử sai rồi, không cho lặp lại
    if (choice === q.answer) {
      setPicked(choice);
      setSolved(true);
      // Chỉ cộng điểm nếu đây là lần thử đầu tiên (chưa có wrong pick nào).
      if (wrongPicks.length === 0) setScore((s) => s + 1);
    } else {
      setWrongPicks((prev) => [...prev, choice]);
      setPicked(choice);
    }
  }

  function checkFill() {
    const correct = fillValue.trim().toLowerCase() === String(q.answer).trim().toLowerCase();
    if (correct) setScore((s) => s + 1);
    setPicked('submitted');
    setSolved(true);
  }

  function next() {
    if (isLast) {
      setDone(true);
      if (typeof window !== 'undefined') {
        window.localStorage.setItem(
          storageKey,
          JSON.stringify({ completed: true, score, total: questions.length, ts: Date.now() }),
        );
      }
      return;
    }
    setIndex((i) => i + 1);
    setPicked(null);
    setWrongPicks([]);
    setSolved(false);
    setFillValue('');
  }

  function reset() {
    setIndex(0);
    setPicked(null);
    setWrongPicks([]);
    setSolved(false);
    setFillValue('');
    setScore(0);
    setDone(false);
  }

  if (done) {
    return (
      <div className={styles.quiz}>
        <h4>Hoàn thành bài kiểm tra</h4>
        <p>Bạn đạt <strong>{score} / {questions.length}</strong> điểm (chỉ tính các câu đúng ngay lần đầu).</p>
        <button className={styles.button} onClick={reset}>Làm lại</button>
      </div>
    );
  }

  // Trạng thái hiển thị feedback cho câu hiện tại.
  const showFeedback =
    (q.type === 'mcq' && (solved || wrongPicks.length > 0)) ||
    (q.type === 'fill' && picked === 'submitted');

  const isCorrect = solved && (
    q.type === 'mcq'
      ? picked === q.answer
      : fillValue.trim().toLowerCase() === String(q.answer).trim().toLowerCase()
  );

  return (
    <div className={styles.quiz}>
      <div className={styles.progress}>Câu hỏi {index + 1} / {questions.length}</div>
      <p className={styles.prompt}>{q.prompt}</p>

      {q.type === 'mcq' && (
        <ul className={styles.choices}>
          {q.choices.map((choice) => {
            const isAnswer = choice === q.answer;
            const isWrongAttempt = wrongPicks.includes(choice);
            // Sau khi đã giải đúng, làm nổi bật câu trả lời đúng.
            // Khi chưa giải xong, chỉ làm nổi bật các câu đã thử và sai.
            const cls = [
              styles.choice,
              solved && isAnswer ? styles.correct : '',
              isWrongAttempt ? styles.wrong : '',
            ].join(' ');
            return (
              <li key={choice}>
                <button
                  className={cls}
                  onClick={() => pickMcq(choice)}
                  disabled={solved || isWrongAttempt}
                >
                  {choice}
                </button>
              </li>
            );
          })}
        </ul>
      )}

      {q.type === 'fill' && (
        <div className={styles.fill}>
          <input
            type="text"
            value={fillValue}
            onChange={(e) => setFillValue(e.target.value)}
            disabled={picked === 'submitted'}
            placeholder="Nhập câu trả lời của bạn…"
          />
          {picked !== 'submitted' && (
            <button className={styles.button} onClick={checkFill} disabled={!fillValue.trim()}>
              Kiểm tra
            </button>
          )}
        </div>
      )}

      {showFeedback && (
        <div className={isCorrect ? styles.feedbackOk : styles.feedbackBad}>
          <strong>
            {isCorrect
              ? (q.type === 'mcq' && wrongPicks.length > 0
                  ? 'Đúng rồi.'
                  : 'Chính xác.')
              : (q.type === 'mcq'
                  ? 'Chưa đúng — hãy thử lại với một lựa chọn khác.'
                  : 'Chưa đúng.')}
          </strong>
          {q.explanation && <span> {q.explanation}</span>}
          {!isCorrect && q.type === 'fill' && (
            <span> Đáp án đúng: <code>{q.answer}</code></span>
          )}
        </div>
      )}

      {solved && (
        <button className={styles.button} onClick={next}>
          {isLast ? 'Kết thúc' : 'Câu tiếp theo'}
        </button>
      )}
    </div>
  );
}
