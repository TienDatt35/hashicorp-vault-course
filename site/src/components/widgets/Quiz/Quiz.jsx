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
 * Score and completion are persisted in localStorage under `vault-course:quiz:<lessonId>`
 * so learners see their progress across visits. No backend required.
 */
export default function Quiz({ lessonId, questions = [] }) {
  const storageKey = `vault-course:quiz:${lessonId}`;
  const [index, setIndex] = useState(0);
  const [picked, setPicked] = useState(null);
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
  const submitted = picked !== null || (q.type === 'fill' && fillValue !== '' && picked === 'submitted');

  function check() {
    let correct = false;
    if (q.type === 'mcq') {
      correct = picked === q.answer;
    } else {
      correct = fillValue.trim().toLowerCase() === String(q.answer).trim().toLowerCase();
      setPicked('submitted');
    }
    if (correct) setScore((s) => s + 1);
  }

  function next() {
    if (isLast) {
      setDone(true);
      if (typeof window !== 'undefined') {
        window.localStorage.setItem(
          storageKey,
          JSON.stringify({ completed: true, score: score, total: questions.length, ts: Date.now() }),
        );
      }
      return;
    }
    setIndex((i) => i + 1);
    setPicked(null);
    setFillValue('');
  }

  function reset() {
    setIndex(0);
    setPicked(null);
    setFillValue('');
    setScore(0);
    setDone(false);
  }

  if (done) {
    return (
      <div className={styles.quiz}>
        <h4>Hoàn thành bài kiểm tra</h4>
        <p>Bạn đạt <strong>{score} / {questions.length}</strong> điểm.</p>
        <button className={styles.button} onClick={reset}>Làm lại</button>
      </div>
    );
  }

  const isCorrect = q.type === 'mcq'
    ? picked === q.answer
    : (picked === 'submitted' && fillValue.trim().toLowerCase() === String(q.answer).trim().toLowerCase());

  return (
    <div className={styles.quiz}>
      <div className={styles.progress}>Câu hỏi {index + 1} / {questions.length}</div>
      <p className={styles.prompt}>{q.prompt}</p>

      {q.type === 'mcq' && (
        <ul className={styles.choices}>
          {q.choices.map((choice) => {
            const chosen = picked === choice;
            const showResult = picked !== null;
            const isAnswer = choice === q.answer;
            const cls = [
              styles.choice,
              chosen ? styles.chosen : '',
              showResult && isAnswer ? styles.correct : '',
              showResult && chosen && !isAnswer ? styles.wrong : '',
            ].join(' ');
            return (
              <li key={choice}>
                <button
                  className={cls}
                  onClick={() => picked === null && setPicked(choice)}
                  disabled={picked !== null}
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
            <button className={styles.button} onClick={check} disabled={!fillValue.trim()}>
              Kiểm tra
            </button>
          )}
        </div>
      )}

      {picked !== null && (
        <div className={isCorrect ? styles.feedbackOk : styles.feedbackBad}>
          <strong>{isCorrect ? 'Chính xác.' : 'Chưa đúng.'}</strong>
          {q.explanation && <span> {q.explanation}</span>}
          {!isCorrect && q.type === 'fill' && (
            <span> Đáp án đúng: <code>{q.answer}</code></span>
          )}
        </div>
      )}

      {picked !== null && (
        <button className={styles.button} onClick={next}>
          {isLast ? 'Kết thúc' : 'Câu tiếp theo'}
        </button>
      )}
    </div>
  );
}
